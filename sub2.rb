#! /usr/bin/ruby
#author newdongyuwei@gmail.com
require 'rubygems'
require "redis"
require "oauth"
require "cgi"
require 'uri'
require "tmail"
require "yaml"
require 'weibo'
require 'logger'
require 'haml'
require 'pony'

redis = Redis.new(:thread_safe=>true)

trap(:INT) { puts; exit }

Weibo::Config.api_key = "1869125062"
Weibo::Config.api_secret = "d128d7a473c7a06ba0b84284a24c7924"

loger = Logger.new(File.join(File.dirname(__FILE__),'sub2.log'))
loger.level = Logger::DEBUG

def parse_mail(mail,data)
        if mail.multipart?
            if mail.has_attachments?
                attachment = mail.attachments.first
                name = attachment.original_filename or '.attachment'
                File.open(name,"w+") { |f|
                    f << attachment.gets(nil)
                }
                
                data[:attachment] =  name
            end

            mail.parts.each do |m|
                m.base64_decode
                if m.multipart?
                    parse_mail(m,data)
                else
                    if m.content_type == 'text/plain'
                        data[:body] = m.body
                    end
                end
            end
        else
            data[:body] = mail.body
        end
end

def get_mail_body_and_attachment(mail)
    data = {}
    parse_mail(mail,data)
    data[:body] = data[:body] || ""
    data[:body] = data[:body].slice(0,280).strip#140*2
    return data
end

def publish_pic_and_status(token,status,attachment)
    if token
        arr = token.split("&")
        oauth = Weibo::OAuth.new(Weibo::Config.api_key, Weibo::Config.api_secret)
        oauth.authorize_from_access(arr[0], arr[1])
        if attachment and (File.exists? attachment)
            begin
                Weibo::Base.new(oauth).upload(status, File.open(attachment,'r'))
            rescue Exception=>e
                puts e.to_str
            end
            File.delete attachment
        else
            begin
                Weibo::Base.new(oauth).update(status)
            rescue Exception=>e
                puts e.to_str
            end
        end 
    end
end

def send_mail to,subject,body
    Pony.mail(:to => to, :from => 'weibo@session.im', :subject => subject, :body => body,:tls => true)
end

def friends_timeline token,to
    if token
        arr = token.split("&")
        oauth = Weibo::OAuth.new(Weibo::Config.api_key, Weibo::Config.api_secret)
        oauth.authorize_from_access(arr[0], arr[1])
        @timeline = Weibo::Base.new(oauth).friends_timeline
        begin
             body = Haml::Engine.new(File.read("./views/friends_timeline.haml")).render(self)
             send_mail(to,"weibo friends timeline",body)
        rescue Exception=>e
            puts e.to_str
        end 
    end
end

redis.subscribe(:verify,:email,:friends_timeline) do |on|
    on.message do |channel, message|
        puts channel    
        begin
            mail = TMail::Mail.parse(message)
            redis2 = Redis.connect
            token = redis2.get(mail.from[0])
            puts "token: #{token}"

            if mail
                body_attachment = get_mail_body_and_attachment(mail)
                body = body_attachment[:body]
                attachment = body_attachment[:attachment]

                if channel == 'friends_timeline'
                    friends_timeline(token,message)
                    return
                end

                if channel == 'verify'
                    if not token
                        redis2.set(mail.from[0],body) 
                    end
                end

                if channel == 'email'
                    publish_pic_and_status(token,body,attachment)
                end
            else
                puts "error when TMail::Mail.parse "
            end    
        rescue Exception=>e
            puts e.to_str
        end
    end
end

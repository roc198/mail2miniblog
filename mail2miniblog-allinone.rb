#! /usr/bin/ruby
#by newdongyuwei@gmail.com
#mail2miniblog all in one

if GC.respond_to?(:copy_on_write_friendly=)
   GC.copy_on_write_friendly = true
end

require 'rubygems'   
require "sinatra"  
require "sinatra/base"  
require  'oauth'
require 'oauth/consumer'

require 'eventmachine'
require 'ostruct'
require 'redis'

require "cgi"
require "tmail"

require 'logger'

class Mail2MiniBlog  <  Sinatra::Base
    enable :sessions
    set  :run ,true
    
    def new_consumer(api_key='1869125062', api_key_secret='d128d7a473c7a06ba0b84284a24c7924')
        return OAuth::Consumer.new(api_key, api_key_secret , 
                                        { 
                                          :site=>"http://api.t.sina.com.cn",
                                          :request_token_path=>"/oauth/request_token",
                                          :access_token_path=>"/oauth/access_token",
                                          :authorize_path=>"/oauth/authorize",
                                          :signature_method=>"HMAC-SHA1",
                                          :scheme=>:header,
                                          :realm=>"http://session.im"
                                        }
         )
    end

    get '/' do
        consumer = self.new_consumer()
        request_token = consumer.get_request_token
        session[:request_token] = request_token.token 
        session[:request_token_secret] = request_token.secret 
	    href = request_token.authorize_url + "&oauth_callback=" + CGI.escape("http://session.im/callback")
	    '邮件发微博:
	    <br>授权<a href="' + href + '" title="mail2miniblog">邮件发(SINA)微博</a>'
    end

    get '/callback' do
        request_token = OAuth::RequestToken.new(self.new_consumer(), session[:request_token], session[:request_token_secret]) 
        access_token = request_token.get_access_token(:oauth_verifier => params[:oauth_verifier]) 
        session['access_token'] = access_token.token
        session['access_secret'] = access_token.secret
        "To bind your email,please send an email to v@session.im(the mail content MUST be #{session['access_token']}&#{session['access_secret']})<br>After your mail verified, to publish a sina weibo(miniblog),U can just send an email to t@session.im"
    end
end

class EmailServer < EM::P::SmtpServer
    @host ="session.im"#'127.0.0.1'
    @port = 25#lsof -i:25
    def receive_plain_auth(user, pass)
        true
    end

    def get_server_domain
        @host
    end

    def get_server_greeting
        "#{@host} smtp server greets you with impunity"
    end

    def receive_sender(sender)
        current.sender = sender
        true
    end

    def receive_recipient(recipient)
        puts recipient
	    if recipient.strip.index("t@session.im") or recipient.strip.index("v@session.im")
            	current.recipient = recipient
		    true
	    else
		    false
	    end
    end

    def receive_message
        current.received = true
        current.completed_at = Time.now
        p [:received_email, current]
        redis = Redis.connect
	    if current.recipient.strip.index 't@session.im'
            	redis.publish(:email,current.data)
	    else
            	redis.publish(:verify,current.data)
	    end
        @current = OpenStruct.new
        true
    end

    def receive_ehlo_domain(domain)
        @ehlo_domain = domain
        true
    end

    def receive_data_command
        current.data = ""
        true
    end

    def receive_data_chunk(data)
        current.data << data.join("\n")
        true
    end

    def receive_transaction
        if @ehlo_domain
            current.ehlo_domain = @ehlo_domain
            @ehlo_domain = nil
        end
        true
    end

    def current
        @current ||= OpenStruct.new
    end

    def self.start(host = @host, port = @port)
        @server = EM.start_server host, port, self
    end

    def self.stop
        if @server
            EM.stop_server @server
            @server = nil
        end
    end

    def self.running?
        !!@server
    end
    end

EM.run do
    EmailServer.start
    
    Mail2MiniBlog .run!
    
    def consumer(api_key='1869125062', api_key_secret='d128d7a473c7a06ba0b84284a24c7924')
        return OAuth::Consumer.new(api_key, api_key_secret ,
                                        {
                                          :site=>"http://api.t.sina.com.cn",
                                          :request_token_path=>"/oauth/request_token",
                                          :access_token_path=>"/oauth/access_token",
                                          :authorize_path=>"/oauth/authorize",
                                          :signature_method=>"HMAC-SHA1",
                                          :scheme=>:header,
                                          :realm=>"http://session.im"
                                        }
         )
    end
    
    def update_status(token,status)
        arr = token.split("&")
        access_token = OAuth::AccessToken.new(new_consumer(),arr[0],arr[1])
        if access_token
            access_token.post("http://api.t.sina.com.cn/statuses/update.json",{"status" => CGI.escape(status) })
        end
    end
    
    loger = Logger.new(File.join(File.dirname(__FILE__),'all.log'))
    loger.level = Logger::DEBUG
  
    redis = Redis.new(:thread_safe=>true)
    redis.subscribe(:verify,:email) do |on|
        on.message do |channel, message|
            loger.debug(channel)
            loger.debug(message)
            begin
                mail = TMail::Mail.parse(message)
                if mail
                    puts mail
                    p mail.to,mail.from
                    body = ''
                    if mail.multipart? 
                        mail.parts.each do |m|
                            if m.content_type == "text/plain"
                                body = m.body
                            end
                        end
                    else
                        body = mail.body
                    end
                    body = body.slice(0,420).strip#140*3
                    loger.debug(body)
                    
                    redis2 = Redis.connect
                    token = redis2.get(mail.from[0])
                    loger.debug("token: #{token}")
                    if channel == 'verify'
		                if not token
                            		redis2.set(mail.from[0],body.strip) 
		                end
                        else#channel is 'email',meaning to publish miniblog
                            if token
                                update_status(token,body)
                            end
                    end
                else
                    puts "error when TMail::Mail.parse "
                end    
            rescue Exception=>e
                loger.error(e.to_str)
            end
        end
    end
end

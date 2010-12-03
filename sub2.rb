#! /usr/bin/ruby
#author newdongyuwei@gmail.com
require 'rubygems'
require "redis"
require "oauth"
require "cgi"
require 'uri'
require "tmail"
require "yaml"
require 'net/http'
require 'net/http/post/multipart'

redis = Redis.new(:thread_safe=>true)

trap(:INT) { puts; exit }

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

def part_filename(part)
    file_name = (part['content-location'] &&part['content-location'].body) ||
    part.sub_header("content-type", "name") ||part.sub_header("content-disposition", "filename")
    return file_name.strip
end

def get_mail_body_and_attachment(mail)
    puts mail
    p mail.to,mail.from
    body = ''
    attachment = []
    if mail.multipart? 
        mail.parts.each do |part|
            if part.content_type == "text/plain"
                body = part.body
            end
            if part.transfer_encoding  == "base64" and attachment.length == 0# just parse first attachment
                filename = part_filename(part)
                part.base64_decode
                filepath = File.join(File.dirname(__FILE__) ,  filename)
                puts filepath
                attachment << filepath
                File.open(filepath,File::CREAT|File::TRUNC|File::WRONLY,0644){ |f|
                    f.write(part.body)
                }
            end
        end
    else
        body = mail.body
    end
    body = body.slice(0,420).strip#140*3
    p body
    return {'body' => body,'attachment' => attachment}
end

def update_status(token,status)
    arr = token.split("&")
    access_token = OAuth::AccessToken.new(new_consumer(),arr[0],arr[1])
    if access_token
            	access_token.post("http://api.t.sina.com.cn/statuses/update.json",{"status" => CGI.escape(status) })
    end
end

#borrow from http://bitbucket.org/dropboxapi/dropbox-client-ruby/src/b7118ab96791/lib/dropbox.rb
def sign(request,consumer,access_token, request_options = {})
    consumer.sign!(request, access_token, request_options)
end

def publish_pic_and_status(token,status,file_obj)
    arr = token.split("&")
    consumer = new_consumer()
    access_token  = OAuth::AccessToken.new(consumer ,arr[0],arr[1])
    url = URI.parse('http://api.t.sina.com.cn/statuses/upload.json')
    name = "pic"
    oauth_fake_req = Net::HTTP::Post.new(url.path)
    oauth_fake_req.set_form_data({ "file" => name,"status"=>CGI.escape(status) })
    sign(oauth_fake_req,consumer,access_token, {
          :site=>"http://api.t.sina.com.cn",
          :request_token_path=>"/oauth/request_token",
          :access_token_path=>"/oauth/access_token",
          :authorize_path=>"/oauth/authorize",
          :signature_method=>"HMAC-SHA1",
          :scheme=>:header,
          :realm=>"http://session.im"
        })
    oauth_sig = oauth_fake_req.to_hash['authorization']

    req = Net::HTTP::Post::Multipart.new(url.path, {
        "file" => UploadIO.convert!(file_obj, 
                    "application/octet-stream", name, name),
    })
    puts "oauth_sig #{oauth_sig}"
    req['authorization'] = oauth_sig.join(", ")
    puts '-----------------------------------------------'
    puts req['authorization'] 
    res = Net::HTTP.start(url.host, url.port) do |http|
        puts '++++++++++++++++++++++++++++'
        puts http.request(req)
    end
    puts '-------------end------------------------------'
    puts res
end

redis.subscribe(:verify,:email) do |on|
    on.message do |channel, message|
        puts channel
        puts message
        begin
            mail = TMail::Mail.parse(message)
            if mail
                body_attachment = get_mail_body_and_attachment(mail)
                body = body_attachment['body']
                attachment = body_attachment['attachment'][0]
                redis2 = Redis.connect
                token = redis2.get(mail.from[0])
                puts "token: #{token}"
                if channel == 'verify'
		            if not token
                        		redis2.set(mail.from[0],body) 
		            end
                    else#channel is 'email',meaning to publish miniblog
                        if token
                            #update_status(token,body)
                            publish_pic_and_status(token,body,attachment)
                        end
                end
            else
                puts "error when TMail::Mail.parse "
            end    
        rescue Exception=>e
            file = File.open("/opt/hg/mail2miniblog/sub.error","w")
            file.puts(e.to_str)
            file.close
        end
    end
end

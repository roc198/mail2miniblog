require 'rubygems'
require "redis"
require "oauth"
require "cgi"
require "tmail"

redis = Redis.new(:thread_safe=>true)

trap(:INT) { puts; exit }

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


redis.subscribe(:verify,:email) do |on|
    on.message do |channel, message|
        puts channel
        puts message
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
                p body
                
                redis2 = Redis.connect
                token = redis2.get(mail.from[0])
                puts "token: #{token}"
                if channel == 'verify'
		            if not token
                        		redis2.set(mail.from[0],body.strip) 
		            end
                    else#channel is 'email',meaning to publish miniblog
                        if token
                            arr = token.split("&")
                            access_token = OAuth::AccessToken.new(consumer(),arr[0],arr[1])
		                    if access_token
                                    	access_token.post("http://api.t.sina.com.cn/statuses/update.json",{"status" => CGI.escape(body) })
		                    end
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


#! /usr/bin/ruby
# encoding: UTF-8
#by newdongyuwei@gmail.com
#mail2weibo, using mailgun.org's mailhook service

if GC.respond_to?(:copy_on_write_friendly=)
   GC.copy_on_write_friendly = true
end

%w(rubygems sinatra  eventmachine redis oauth cgi uri yaml weibo  json haml pony date).each{|lib|require lib}

class Mail2Weibo  <  Sinatra::Base
    enable :sessions
    set :run ,true
    set :port, 8888
    set :environment, :production
    set :logging, true

    REDIS = Redis.new()
    Weibo::Config.api_key = "1869125062"
	Weibo::Config.api_secret = "d128d7a473c7a06ba0b84284a24c7924"

    def new_consumer(api_key= Weibo::Config.api_key, api_key_secret=Weibo::Config.api_secret)
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
        consumer = new_consumer()
        request_token = consumer.get_request_token
        session[:request_token] = request_token.token 
        session[:request_token_secret] = request_token.secret 
        href = request_token.authorize_url + "&oauth_callback=" + CGI.escape("http://mail2weibo.session.im/weibo/callback")
        "<div>授权<a href='#{href}'>邮件收发(新浪)微博</a></div>"
    end
    
	get '/weibo/callback' do
		request_token = OAuth::RequestToken.new(new_consumer(), session[:request_token], session[:request_token_secret]) 
        access_token = request_token.get_access_token(:oauth_verifier => params[:oauth_verifier]) 
		
		"<ul>
			<li>绑定邮箱,请发邮件到 v@weibo.mailgun.org (邮件 <b>主题</b> 必须为  #{access_token.token}&#{access_token.secret} 邮件内容可以为空)</li>
			<li></li>
			<li>绑定邮箱后,发邮件到 t@weibo.mailgun.org (邮件 <b>主题</b> 即为微博内容,邮件内容可以为空)即可发布微博</li>
			<li></li>
			<li>读取微博 ,发邮件到 l@weibo.mailgun.org (邮件 主题和内容 均可随意填写,不影响)</li>
		<ul>"

	end

	post '/weibo/v/' do
		subject = params[:subject]
		if subject and subject.index("&")
			arr = subject.split("&")	
			REDIS.set(params[:sender],{:token => arr[0], :secret => arr[1]}.to_json)
			send_mail(params[:sender],'Your weibo account and your mail have binded',"To publish a weibo, you can send  email to  t@weibo.mailgun.org (the email's Subject will be parsed as weibo content,the mail body can be empty);To read your friend's timeline ,you can send email to l@weibo.mailgun.org (the Subject and Body of mail can be anything)")	
		end
	end
		
	post '/weibo/t/' do
		value = REDIS.get(params[:sender])
		if value
			begin
				token_secret = JSON.parse(value)
				if token_secret 
					oauth = Weibo::OAuth.new(Weibo::Config.api_key, Weibo::Config.api_secret)
              		oauth.authorize_from_access(token_secret['token'], token_secret['secret'])
					Weibo::Base.new(oauth).update(params[:subject]) if params[:subject] and params[:subject]!= ""
				end
			rescue Exception=>e
				puts e.to_str
			end
			
		end
	end

	def friends_timeline token,to
      if token
          arr = token.split("&")
          oauth = Weibo::OAuth.new(Weibo::Config.api_key, Weibo::Config.api_secret)
          oauth.authorize_from_access(arr[0], arr[1])
          @timeline = Weibo::Base.new(oauth).friends_timeline({ 'count' => 50})
          begin
               body = Haml::Engine.new(File.read("./views/friends_timeline.haml")).render(self)
               send_mail(to,"weibo friends timeline",body)
          rescue Exception=>e
              puts e.to_str
          end 
      end
  end

	post '/weibo/l/' do
		value = REDIS.get(params[:sender])
		if value
			begin
				token_secret = JSON.parse(value)
				if token_secret 
					oauth = Weibo::OAuth.new(Weibo::Config.api_key, Weibo::Config.api_secret)
          			oauth.authorize_from_access(token_secret['token'],token_secret['secret'])
          			@timeline = Weibo::Base.new(oauth).friends_timeline({ 'count' => 30})
          			begin
		               body = Haml::Engine.new(File.read("./views/friends_timeline.haml")).render(self)
		               send_mail(params[:sender],"weibo friends timeline",body)
		          	rescue Exception=>e
		              puts e.to_str
		         	end 
				end
			rescue Exception=>e
				puts e.to_str
			end
		end
	end
	get '/test' do
		EM::next_tick do 
			puts 'EM::next_tick'
		end
		'EM::next_tick replace Thread.new'
	end

	def send_mail to,subject,body
		EM::next_tick do 
			Pony.mail(
				:to => to, 
				:from => 'weibo@session.im', 
				:subject => subject,
				:html_body => body,
				:via => :smtp, :via_options => {
				    :address => 'smtp.gmail.com',
				    :port => '587',
				    :user_name => 'mail2weibo',#modify it
				    :password => 'mail2weibo',#modify it
				    :enable_starttls_auto => true,
				    :authentication => :plain,  
				    :domain => "session.im"
				}
			)
		end

        #Thread.new do end
	end
end



EM.epoll

EM.run do
	Mail2Weibo.run!
end


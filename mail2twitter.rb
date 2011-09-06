#! /usr/bin/ruby
# encoding: UTF-8
#by newdongyuwei@gmail.com
#mail2twitter
#$KCODE = "UTF-8"

if GC.respond_to?(:copy_on_write_friendly=)
   GC.copy_on_write_friendly = true
end
%w(rubygems sinatra  redis twitter_oauth json cgi uri  pony).each{|lib|require lib}

def send_mail to,subject,body
  Pony.mail(
    :to => to, 
    :from => 'weibo@session.im', 
    :subject => subject,
    :html_body => body,
    :via => :smtp, :via_options => {
	:address => 'smtp.gmail.com',
	:port => '587',
	:user_name => 'xxx_name',#modify it
	:password => 'xxx_password',
	:enable_starttls_auto => true,
	:authentication => :plain,  
	:domain => "session.im"
    }
  )
end



enable :sessions
set :run ,true
set :port, 6789
set :environment, :production
set :logging, true
REDIS = Redis.new(:thread_safe => true,:db => 2)
@@consumer_key = '8BMVUFdK5HhUvPafrmw9w'
@@consumer_secret = 'dZH43hGFF1df3x3wCcBvlzAiGFPhrU0rU67nj6IeJs'

get '/twitter/' do 
	@@client = TwitterOAuth::Client.new(
	    :consumer_key => @@consumer_key ,
	    :consumer_secret => @@consumer_secret  
	)
	request_token = @@client.request_token(:oauth_callback => CGI.escape("http://session.im:6789/twitter/callback"))
	session['twitter_request_token'] = request_token.token
	session['twitter_request_secret'] = request_token.secret
	puts request_token.authorize_url
	href = request_token.authorize_url + "&oauth_callback=#{CGI.escape('http://session.im:6789/twitter/callback')}"
	"<div>authorize:<a href='#{href}'>mail2Twitter</a></div>"
end

get '/twitter/callback' do
	access_token = @@client.authorize(
		session['twitter_request_token'],
		session['twitter_request_secret'],
		:oauth_verifier => params[:oauth_verifier]
	)
	
	"<ul>
		<li>绑定邮箱请发送邮件到 v@twitter.mailgun.org(邮件<bold>标题</bold>必须是 #{access_token.token}&#{access_token.secret})</li>
		<li>邮箱绑定后，发送邮件到 t@twitter.mailgun.org 即可发微博---邮件<bold>标题</bold>即发布为微博</li>
		<li>阅读订阅的twitter发邮件到l@twitter.mailgun.org</li>
	<ul>"

end


post '/twitter/v/' do
	subject = params[:subject]
	if subject and subject.index("&")
		arr = subject.split("&")	
		REDIS.set(params[:sender],{:token => arr[0], :secret => arr[1]}.to_json)
	end
end
	
post '/twitter/t/' do
	value = REDIS.get(params[:sender])
	if value
		begin
			token_secret = JSON.parse(value)
			if hash
				client = TwitterOAuth::Client.new(
				    :consumer_key => @consumer_key,
				    :consumer_secret => @consumer_secret ,
				    :token => token_secret[:token], 
				    :secret => token_secret[:secret]
				)
				client.update(params[:subject]) if params[:subject] and params[:subject]!= ""
			end
		rescue Exception=>e
			puts e.to_str
		end
		
	end
end

post '/twitter/l/' do
	value = REDIS.get(params[:sender])
	if value
		begin
			token_secret = JSON.parse(value)
			if hash
				client = TwitterOAuth::Client.new(
				    :consumer_key => @consumer_key,
				    :consumer_secret => @consumer_secret ,
				    :token => token_secret[:token], 
				    :secret => token_secret[:secret]
				)
				send_mail(params[:sender],'twitter friend timeline',client.friends_timeline)		
			end
		rescue Exception=>e
			puts e.to_str
		end
	end
end




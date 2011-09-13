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
	request_token = @@client.request_token(:oauth_callback => "http://session.im:6789/twitter/callback")
	session['twitter_request_token'] = request_token.token
	session['twitter_request_secret'] = request_token.secret
	href = request_token.authorize_url + "&oauth_callback=http://session.im:6789/twitter/callback"
	"<div>authorize:<a href='#{href}'>mail2Twitter</a></div>"
end

get '/twitter/callback' do
	access_token = @@client.authorize(
		session['twitter_request_token'],
		session['twitter_request_secret'],
		:oauth_verifier => params[:oauth_verifier]
	)
	
	"<ul>
		<li>To bind email,you just need send an email to  v@twitter.mailgun.org (the email's <bold>Subject</bold> Must be  #{access_token.token}&#{access_token.secret})</li>
		<li></li>
		<li>After your email binded, to publish a twitter, you can send  email to  t@twitter.mailgun.org (the email's<bold>Subject</bold> will be parsed as twitter,the mail body can be empty)</li>
		<li></li>
		<li>To read your friend's timeline ,you can send email to l@twitter.mailgun.org (the Subject and Body of mail can be anything)</li>
	<ul>"

end


post '/twitter/v/' do
	subject = params[:subject]
	if subject and subject.index("&")
		arr = subject.split("&")	
		REDIS.set(params[:sender],{:token => arr[0], :secret => arr[1]}.to_json)
		send_mail(params[:sender],'your twitter account and mail binded',"To publish a twitter, you can send  email to  t@twitter.mailgun.org (the email's Subject will be parsed as twitter,the mail body can be empty);To read your friend's timeline ,you can send email to l@twitter.mailgun.org (the Subject and Body of mail can be anything)")	
	end
end
	
post '/twitter/t/' do
	value = REDIS.get(params[:sender])
	if value
		begin
			token_secret = JSON.parse(value)
			if token_secret 
				client = TwitterOAuth::Client.new(
				    :consumer_key => @@consumer_key,
				    :consumer_secret => @@consumer_secret ,
				    :token => token_secret['token'], 
				    :secret => token_secret['secret']
				)
				puts client.authorized?
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
			if token_secret 
				client = TwitterOAuth::Client.new(
				    :consumer_key => @@consumer_key,
				    :consumer_secret => @@consumer_secret ,
				    :token => token_secret['token'], 
				    :secret => token_secret['secret']
				)
				puts client.authorized?
				send_mail(params[:sender],'twitter friend timeline',client.friends_timeline)		
			end
		rescue Exception=>e
			puts e.to_str
		end
	end
end




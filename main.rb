require 'rubygems'   
require "sinatra"  
require  'oauth'
require 'oauth/consumer'

enable :sessions

def new_Consumer(api_key='1869125062', api_key_secret='d128d7a473c7a06ba0b84284a24c7924')
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
    @consumer = new_Consumer()
    @request_token = @consumer.get_request_token
    session[:request_token] = @request_token.token 
    session[:request_token_secret] = @request_token.secret 
	href = @request_token.authorize_url + "&oauth_callback=" + CGI.escape("http://session.im/callback")
	'To bind your email,please send an email to v@session.im;<br>
	After your mail verified, to publish a sina weibo(miniblog),U can just send an email to t@session.im
	<br>First please visit <a href="' + href + '" title="mail2miniblog">mail2sina miniblog(weibo)</a>'
end

get '/callback' do
    request_token = OAuth::RequestToken.new(new_Consumer(), session[:request_token], session[:request_token_secret]) 
    @access_token = request_token.get_access_token(:oauth_verifier => params[:oauth_verifier]) 
    session['access_token'] = @access_token.token
    session['access_secret'] = @access_token.secret
    "To bind your email,please send an email to v@session.im(the mail content MUST be #{session['access_token']}&#{session['access_secret']})<br>After your mail verified, to publish a sina weibo(miniblog),U can just send an email to t@session.im"
end

set  :run ,true

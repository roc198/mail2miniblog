#! /usr/bin/ruby
#author newdongyuwei@gmail.com

if GC.respond_to?(:copy_on_write_friendly=)
   GC.copy_on_write_friendly = true
end

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
	'<div>邮件收发微博:<br>授权<a href="' + href + '" title="mail2miniblog">邮件发(SINA)微博</a</div><div><a href="http://code.google.com/p/mail2miniblog" target="_blank">本站源码</a></div><hr><div><a href="http://weibo.session.im" target="_blank">分享微博订阅</a></div>'
end

get '/callback' do
    request_token = OAuth::RequestToken.new(new_Consumer(), session[:request_token], session[:request_token_secret]) 
    @access_token = request_token.get_access_token(:oauth_verifier => params[:oauth_verifier]) 
    session['access_token'] = @access_token.token
    session['access_secret'] = @access_token.secret
    "<ul><li>绑定邮箱请发送邮件到 v@session.im(邮件内容必须是 #{session['access_token']}&#{session['access_secret']})</li><li>邮箱绑定后，发送邮件到 t@session.im 即可发微博---邮件内容即发布为微博，同时第一个图片附件会自动被发布为微博图片</li><li>阅读订阅的微博发邮件到l@session.im</li><ul>"
end

set  :run ,true

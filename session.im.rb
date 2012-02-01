#! /usr/bin/ruby
#by newdongyuwei@gmail.com
#mail2miniblog all in one

if GC.respond_to?(:copy_on_write_friendly=)
   GC.copy_on_write_friendly = true
end

%w(rubygems sinatra).each{|lib|require lib}

enable :sessions
set :run ,true
set :port, 3000
set :environment, :production
set :logging, true

get '/' do
    "<div><a href='http://mail2weibo.session.im'>邮件收发(SINA)微博</a></div>
    <div><a href='http://session.im:9876/'>邮件发(SINA)微博---支持图片附件发布为微博图片</a></div>
    <hr><div><a href='http://code.google.com/p/mail2miniblog' target='_blank'>本站源码</a></div>
    <hr><div><a href='http://ruby.session.im' target='_blank'>try Ruby on WebSocket</a></div>
    <hr><div><a href='http://twitter.session.im' target='_blank'>mail2twitter(邮件发twitter)</a></div>
    <hr><div><a href='http://weibo.session.im' target='_blank'>分享微博订阅</a></div>"
end


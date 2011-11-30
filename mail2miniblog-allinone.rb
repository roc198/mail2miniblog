#! /usr/bin/ruby
#by newdongyuwei@gmail.com
#mail2miniblog all in one

if GC.respond_to?(:copy_on_write_friendly=)
   GC.copy_on_write_friendly = true
end

%w(rubygems sinatra eventmachine em-proxy ostruct redis oauth cgi uri  tmail yaml weibo  haml pony date).each{|lib|require lib}

class Mail2MiniBlog  <  Sinatra::Base
    enable :sessions
    set :run ,true
    set :port, 3000
    set :environment, :production
    set :logging, true
    
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
        "<div>邮件收发微博:<br>授权<a href='#{href}'>邮件发(SINA)微博</a></div>
        <div><a href='http://code.google.com/p/mail2miniblog' target='_blank'>本站源码</a></div>
        <hr><div><a href='http://ruby.session.im' target='_blank'>try Ruby on WebSocket</a></div>
	<hr><div><a href='http://twitter.session.im' target='_blank'>mail2twitter(邮件发twitter)</a></div>
        <hr><div><a href='http://weibo.session.im' target='_blank'>分享微博订阅</a></div>"
    end
    
    get '/callback' do
        request_token = OAuth::RequestToken.new(new_Consumer(), session[:request_token], session[:request_token_secret]) 
        @access_token = request_token.get_access_token(:oauth_verifier => params[:oauth_verifier]) 
        session['access_token'] = @access_token.token
        session['access_secret'] = @access_token.secret
        "<ul><li>绑定邮箱请发送邮件到 v@session.im(邮件内容必须是 #{session['access_token']}&#{session['access_secret']})</li><li>邮箱绑定后，发送邮件到 t@session.im 即可发微博---邮件内容即发布为微博，同时第一个图片附件会自动被发布为微博图片</li><li>阅读订阅的微博发邮件到l@session.im</li><ul>"
    end
end

class EmailServer < EM::P::SmtpServer
    @host = "127.0.0.1" # "localhost"
    @port = 2525
    def receive_plain_auth(user, pass)
        true
    end

    def get_server_domain
        @host
    end

    def get_server_greeting
        "#{@host} smtp server"
    end

    def receive_sender(sender)
        current.sender = sender
        true
    end

    def receive_recipient(recipient)
        current.recipient = recipient
        rec = recipient.strip.sub("<","").sub(">","")
        if rec == "l@session.im" or rec == "friends_timeline@session.im"
            Redis.connect.publish(:friends_timeline,current.sender.strip.sub("<","").sub(">",""))
            return true
        end

        if rec == "t@session.im" or rec == "v@session.im"
            return true
        else
            return false
        end
    end

    def receive_message
        current.received = true
        current.completed_at = Time.now
        p [:received_email, current]
        redis = Redis.connect
        if current.recipient.strip.index("t@session.im")
            redis.publish(:email,current.data.join(""))
        end
        if current.recipient.strip.index("v@session.im")
            redis.publish(:verify,current.data.join(""))
        end
        @current = OpenStruct.new
        true
    end

    def receive_ehlo_domain(domain)
        @ehlo_domain = domain
        true
    end

    def receive_data_command
        current.data = []
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

EM.epoll

EM.run do
    Proxy.start(:host => "0.0.0.0", :port => 25, :debug => false) do |conn| 
        conn.server :prod, :host => "127.0.0.1", :port => 2525
        conn.server :dev,  :host => "127.0.0.1", :port => 2526
        conn.server :test, :host => "127.0.0.1", :port => 2527
        conn.on_data do |data|
            data
        end

        conn.on_response do |server, resp|
            resp if server == :prod
        end
    end

    EmailServer.start

    Mail2MiniBlog.run!
    
    #redis.subscribe会阻塞---EventMachine is evented and thus single-threaded
    Thread.new do
      redis = Redis.new(:thread_safe=>true)
      
      Weibo::Config.api_key = "1869125062"
      Weibo::Config.api_secret = "d128d7a473c7a06ba0b84284a24c7924"
      
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
      
      redis.subscribe(:verify,:email,:friends_timeline) do |on|
          on.message do |channel, message|
              puts channel    
              if channel == 'friends_timeline'
                  friends_timeline(Redis.connect.get(message),message)
              else
                  begin
                      mail = TMail::Mail.parse(message)
                      redis2 = Redis.connect
                      token = redis2.get(mail.from[0])
                      puts "token: #{token}"
      
                      if mail
                          body_attachment = get_mail_body_and_attachment(mail)
                          body = body_attachment[:body]
                          attachment = body_attachment[:attachment]
      
                          
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
      end
    end
end

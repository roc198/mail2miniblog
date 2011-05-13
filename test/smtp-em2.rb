%w(rubygems eventmachine mailfactory).each{|lib|require lib}
#gem install mailfactory -V

EM.run{
    mail = MailFactory.new
    mail.to = 'xxx@gmail.com'
    mail.from = 'dongyuwei@weibo.com'
    mail.subject = 'hi!'
    #mail.text = 'hello world'
    mail.html = '<h1>hello world</h1><a href="http://weibo.com">weibo.com</a>'

    email = EM::P::SmtpClient.send(
        :from=>mail.from,
        :to=>mail.to,
        :content=>"#{mail.to_s}\r\n.\r\n",
        :header=> {"Subject" => mail.subject},
        :domain=>"session.im",
        :host=>'smtp.gmail.com',
        :port=>587,   
        :starttls=>true,  
        :auth => {
            :type=>:plain, 
            :username=>"xxxx@gmail.com", 
            :password=>"yyyyyyy"
        },
        :verbose => true
    )
    email.callback{
        puts 'Email sent!'
    }
    email.errback{ |e|
        puts 'Email failed!'
    }
}

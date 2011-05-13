require 'rubygems'
require 'eventmachine'

EM.run{
    email = EM::Protocols::SmtpClient.send(
    :domain=>"session.im",
        :host=>'smtp.gmail.com',
        :port=>587,   
        :starttls=>true,  
        :auth => {
            :type=>:plain, 
            :username=>"xxx@gmail.com", 
            :password=>"yyyyy"
        },
        :from=>"weibo@session.im",
        :to=> ["xxxxx@gmail.com"],
        :header=> {"Subject" => "This is a subject line"},
        :body=> "hello world",
        :verbose => true
    )
    email.callback{
        puts 'Email sent!'
    }
    email.errback{ |e|
        puts 'Email failed!'
    }
} 

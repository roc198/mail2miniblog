require 'rubygems'
require 'eventmachine'
require 'daemons'

Daemons.daemonize({
    :backtrace  => true,
    :log_dir    => '/var/log',
    :log_output => true
    
})


class MailHookServer < EM::P::SmtpServer
    @host = "127.0.0.1"
    @port = 2526
    @data = []
    def receive_plain_auth(user, pass)
        true
    end

    def get_server_domain
        @host
    end

    def get_server_greeting
        "session.im smtp server"
    end

    def receive_sender(sender)
        true
    end

    def receive_recipient(recipient)
        rec = recipient.strip.sub("<","").sub(">","")
        puts rec
        true    
    end

    def receive_message    
        true
    end

    def receive_ehlo_domain(domain)
        @ehlo_domain = domain
        true
    end

    def receive_data_command
        true
    end

    def receive_data_chunk(data)
        @data << data.join("\n")
        true
    end

    def receive_transaction
        if @ehlo_domain
            @ehlo_domain = nil
        end
        true
    end

    def self.start(host = @host, port = @port)
        @server = EM.start_server host, port, self
    end
    
    def parse

    end

    def post

    end
end
EM.epoll
EM.run{ MailHookServer.start }


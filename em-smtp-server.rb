require 'rubygems'
require 'eventmachine'
require 'ostruct'
require 'redis'

class EmailServer < EM::P::SmtpServer
    @host = "session.im"
    @port = 25
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

EM.run{ EmailServer.start }


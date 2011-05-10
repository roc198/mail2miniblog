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
        rec = recipient.strip.sub("<","").sub(">","")
        if rec == "l@#{@host}" or rec == "friends_timeline@#{@host}"
            Redis.connect.publish(:friends_timeline,current.sender.strip.sub("<","").sub(">",""))
            return true
        end

        if rec == "t@#{@host}" or rec == "v@#{@host}"
            current.recipient = recipient
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
        if current.recipient.strip.index("t@#{@host}")
            redis.publish(:email,current.data)
        else
            redis.publish(:verify,current.data)
        end
        @current = OpenStruct.new
        true
    end

    def receive_ehlo_domain(domain)
        @ehlo_domain = domain
        true
    end

    def receive_data_command
        current.data = ""
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


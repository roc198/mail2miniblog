require 'rubygems'
require 'gserver'
require 'redis'

class SMTPServer < GServer
  def initialize(*args)
    super(*args)
    @redis = Redis.connect
  end
  def serve(io)
    @mail_msg = []
    @data_mode = false
    puts "Connected"
    io.print "220 hello\r\n"
    loop do
      if IO.select([io], nil, nil, 0.1)
	      data = io.readpartial(4096)
	      @mail_msg << data
	      puts data
	      ok, op = process_line(data)
	      break unless ok
	      io.print op
      end
      break if io.closed?
    end
    @redis.publish(:email,@mail_msg.join(""))
    io.print "221 bye\r\n"
    io.close
  end

  def process_line(line)
    if (line =~ /^(HELO|EHLO)/)
      return true, "220 and..?\r\n"
    end
    if (line =~ /^QUIT/)
      return false, "bye\r\n"
    end
    if (line =~ /^MAIL FROM\:/)
      return true, "220 OK\r\n"
    end
    if (line =~ /^RCPT TO\:/)
      return true, "220 OK\r\n"
    end
    if (line =~ /^DATA/)
      @data_mode = true
      return true, "354 Enter message, ending with \".\" on a line by itself\r\n"
    end
    if (@data_mode) && (line.chomp =~ /^.$/)
      @data_mode = false
      return true, "220 OK\r\n"
    end
    if @data_mode
      return true, ""
    else
      return true, "500 ERROR\r\n"
    end
  end
end

a = SMTPServer.new(25,'session.im',maxConnections = 100)
a.start
a.join

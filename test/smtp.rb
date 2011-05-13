require 'net/smtp'

message = <<MESSAGE_END
1This is an e-mail message to be sent in HTML format
2<b>This is HTML message.</b>
3<h1>This is headline.</h1>
MESSAGE_END

Net::SMTP.start('session.im', 25)do|smtp|
    smtp.set_debug_output $stdout
    smtp.send_message message, 'from@session.im', 'to@session.im'
end


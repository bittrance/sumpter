require 'ione'

require "smtpclient/version"

class BasicParser
  def receive(data)
    status = nil
    parsed = data.each_line.map do |line|
      line.chomp!
      status, msg = line.split(/[ -]+/, 2)
      msg
    end
    parsed.unshift status
  end
end

class InitCommand
  def generate
    nil
  end
end

class EhloCommand
  def initialize(hostname)
    @hostname = hostname
  end

  def generate
    yield "EHLO #{@hostname}\r\n"
  end
end

class MailCommand
  def initialize(sender)
    @sender = sender
  end

  def generate
    yield "MAIL FROM:<#{@sender}>\r\n"
  end
end

class RcptCommand
  def initialize(recipient)
    @recipient = recipient
  end

  def generate
    yield "RCPT TO:<#{@recipient}>\r\n"
  end
end

class DataCommand
  def generate
    yield "DATA\r\n"
  end
end

class PayloadCommand
  def initialize(stream)
    @stream = stream
  end

  def generate
    @stream.each_line do |line|
      yield "#{line}\r\n"
    end
    yield ".\r\n"
  end
end

class QuitCommand
  def generate
    yield "QUIT\r\n"
  end
end

class SendMail
  def initialize(from, to, payload)
    to = to.is_a?(String) ? [to] : to
    @current = InitCommand.new
    @actions = [ EhloCommand.new("client"), MailCommand.new(from) ]
    @actions += to.map { |recipient| RcptCommand.new(recipient) }
    @actions += [ DataCommand.new, PayloadCommand.new(payload), QuitCommand.new ]
    @buffer = ''
  end

  def read(data)
    @buffer << data
    while newline_index = @buffer.index("\r\n")
      line = @buffer.slice!(0, newline_index + 1)
      #@current.parse line
      @current = @actions.shift
      reply = ''
      @current.generate { |data| reply << data }
    end
    reply
  end
end

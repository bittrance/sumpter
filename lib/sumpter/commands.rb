require 'base64'

module Sumpter
  class CommandException < Exception
    attr_reader :result

    def initialize(result)
      @result = result
    end
  end

  class BaseCommand
    def receive(data)
    end

    private

    def maybe_fail(line)
      status, *parsed = line
      if !is_success?(status)
        raise CommandException.new([self] + line)
      end
    end

    def is_success?(code)
      return code >= 200 && code < 300
    end
  end

  class InitCommand < BaseCommand
    def generate
      nil
    end
  end

  class EhloCommand < BaseCommand
    def initialize(hostname)
      @hostname = hostname
    end

    def generate
      yield "EHLO #{@hostname}\r\n"
    end

    def receive(line)
      maybe_fail(line)
      [self] + line
    end
  end

  class PlainAuthCommand < BaseCommand
    def initialize(user, pass)
      @username = user
      @password = pass
    end

    def generate
      hash = Base64.strict_encode64("#{@username}\0#{@username}\0#{@password}")
      yield "AUTH PLAIN #{hash}\r\n"
    end

    def receive(line)
      maybe_fail(line)
      [self] + line
    end
  end

  class MailCommand < BaseCommand
    def initialize(sender)
      @sender = sender
    end

    def generate
      yield "MAIL FROM:<#{@sender}>\r\n"
    end

    def receive(line)
      maybe_fail(line)
    end
  end

  class RcptCommand < BaseCommand
    def initialize(recipient)
      @recipient = recipient
    end

    def generate
      yield "RCPT TO:<#{@recipient}>\r\n"
    end

    def receive(line)
      maybe_fail(line)
    end
  end

  class DataCommand < BaseCommand
    def generate
      yield "DATA\r\n"
    end
  end

  class PayloadCommand < BaseCommand
    def initialize(stream)
      @stream = stream
    end

    def generate
      @stream.each_line do |line|
        yield "#{line}\r\n"
      end
      yield ".\r\n"
    end

    def receive(line)
      maybe_fail(line)
      [self] + line
    end
  end

  class QuitCommand < BaseCommand
    def generate
      yield "QUIT\r\n"
    end

    def receive(line)
      maybe_fail(line)
      [self] + line
    end
  end
end

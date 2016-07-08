module Sumpter
  class BaseCommand
    attr_accessor :promise

    def receive(data)
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

    def receive(lines)
      status, *parsed = lines
      promise.fulfill(parsed)
    end
  end

  class MailCommand < BaseCommand
    def initialize(sender)
      @sender = sender
    end

    def generate
      yield "MAIL FROM:<#{@sender}>\r\n"
    end
  end

  class RcptCommand < BaseCommand
    def initialize(recipient)
      @recipient = recipient
    end

    def generate
      yield "RCPT TO:<#{@recipient}>\r\n"
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

    def receive(lines)
      status, *parsed = lines
      promise.fulfill(status == '250')
    end
  end

  class QuitCommand < BaseCommand
    def generate
      yield "QUIT\r\n"
    end
  end
end

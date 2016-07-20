module Sumpter
  class CommandException < Exception
    attr_reader :result

    def initialize(result)
      @result = result
    end
  end
  
  class BaseCommand
    attr_accessor :promise

    def receive(data)
    end
    
    private

    def complete_intermediate(line)
      status, *parsed = line
      if !is_success?(status)
        @promise.fail(CommandException.new([self] + line))
      end      
    end
    
    def complete_final(line)
      status, *parsed = line
      if is_success?(status)
        @promise.fulfill([self] + line)
      else
        @promise.fail(CommandException.new([self] + line))
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
      complete_final(line)
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
      complete_intermediate(line)
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
      complete_intermediate(line)
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
      complete_final(line)
    end
  end

  class QuitCommand < BaseCommand
    def generate
      yield "QUIT\r\n"
    end
    
    def receive(line)
      complete_final(line)
    end
  end
end

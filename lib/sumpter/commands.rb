require 'base64'
require 'socket'

module Sumpter
  class CommandException < Exception
    attr_reader :result

    def initialize(result)
      @result = result
    end
  end

  class BaseCommand
    attr_accessor :promise

    def is_pipelining?
      false
    end

    def generate
      # TODO: default impl or require impl
      #  raise 'Please implement generate()'
    end

    def receive(data)
      # TODO: default impl or require impl
      #  raise 'Please implement receive(data)'
    end

    private

    def maybe_fail(line)
      status, *parsed = line
      if !is_success?(status)
        raise CommandException.new([self] + line)
      end
    end

    def is_success?(code)
      return code >= 200 && code < 400
    end
  end

  class InitCommand < BaseCommand
    def generate
      nil
    end
  end

  class EhloCommand < BaseCommand
    def initialize(hostname = Socket.gethostname)
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

  class LoginAuthCommand < BaseCommand
    def initialize(user, pass)
      @username = user
      @password = pass
      @state = 'username'
    end

    def generate
      case @state
      when 'username'
        hash = Base64.strict_encode64("#{@username}")
        yield "AUTH LOGIN #{hash}\r\n"
      when 'password'
        hash = Base64.strict_encode64("#{@password}")
        yield "#{hash}\r\n"
      else
        raise CommandException.new('Unexpected phase when performing AUTH LOGIN')
      end
    end

    def receive(line)
      maybe_fail(line)
      case @state
      when 'username'
        @state = 'password'
        return nil
      when 'password'
        @stete = 'done'
        return [self] + line
      end
    end
  end

  class MailCommand < BaseCommand
    def initialize(sender)
      @sender = sender
    end

    def is_pipelining?
      true
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

    def is_pipelining?
      true
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

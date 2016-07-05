require 'ione'

require "smtpclient/version"

class BasicParser
  def initialize
    @buffer = ''
    @line_re = /^(?<code>[0-9]+)(?<sep>[- ]?)(?<message>.*)$/
    @reply = []
  end

  def receive(data)
    @buffer << data
    while newline_index = @buffer.index("\r\n")
      line = @buffer.slice!(0, newline_index + 1)
      line.chomp!
      res = @line_re.match(line)
      @reply << res[:message]
      if res[:sep] == ' ' or res[:sep] == ''
        yield [res[:code]] + @reply
        @reply.clear
      end
    end
  end
end

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

class SendMail
  # TODO: tests for this property
  attr_reader :state

  def initialize(connection)
    @connection = connection
    @actions = []
    @await_reply = []
    @parser = BasicParser.new
    @state = 'pending'
  end

  # TODO: test explicit start
  def start
    # TODO: guard @state == 'pending'
    # TODO: if resulting promse fails, QuitCommand and die
    future = add_action_group [ InitCommand.new, EhloCommand.new("client") ]
    @state = 'idle' # TODO: Test for state
    next_action
    @connection.on_data(&method(:read))
    future
  end

  def send(from, to, payload)
    # TODO: Guard state dead?
    start if @state == 'pending' # FIXME: This is a future!
    to = to.is_a?(String) ? [to] : to
    future = add_action_group [
      MailCommand.new(from),
      *to.map { |recipient| RcptCommand.new(recipient) },
      DataCommand.new,
      PayloadCommand.new(payload)
    ]
    next_action if @state == 'idle'
    future
  end

  def quit
    # TODO: set @state = 'dead' when future completed - with tests!
    add_action_group [ QuitCommand.new ]
  end

  def read(data)
    puts '<- ' + data
    @parser.receive(data) do |lines|
      action = @await_reply.pop
      action.receive lines
      next_action
    end
    @state = 'idle' # TODO: we don't know this
  end

  private

  def add_action_group(group)
    p = Ione::Promise.new
    group.each do |action|
      action.promise = p
      @actions << action
    end
    p.future
  end

  def next_action
    return if @actions.empty?
    @state = 'running'
    action = @actions.shift
    action.generate { |data|
      puts '-> ' + data
      @connection.write data
    }
    @await_reply << action
  end
end

class SmtpClient

  module Factories
    def syncClient(host, port)
      client = SmtpClient.new(host, port)
      Ione::Future.await(client.start)
    end
  end

  extend Factories

  def initialize(host, port)
    @host = host
    @port = port
    @reactor = Ione::Io::IoReactor.new
  end

  def start
    @reactor.start
    .then { @reactor.connect(@host, @port) }
    .then { |conn|
      @handler = SendMail.new(conn)
      @handler.start
    }
    .map(self)
  end

  def send(from, to, message)
    Ione::Future.await(@handler.send(from, to, message))
  end

  def stop
    @handler.quit.then {
      @reactor.stop
    }
  end
end

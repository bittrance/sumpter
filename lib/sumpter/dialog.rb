require 'ione'
require "sumpter/commands"
require "sumpter/parser"

module Sumpter
  class SMTPDialog
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
      future = add_action_group [ EhloCommand.new("client") ]
      @await_reply << InitCommand.new
      @connection.on_data(&method(:read))
      future
    end

    def send(from, to, payload)
      # TODO: Guard state dead?
      # start if @state == 'pending' # FIXME: This is a future!
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
        next_action if @state == 'pending' || @state == 'idle'
      end
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
      @state = 'idle' # TODO: Test for state
    end
  end
end
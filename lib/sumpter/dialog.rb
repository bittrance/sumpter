require 'ione'
require "sumpter/commands"
require "sumpter/parser"

module Sumpter
  class SMTPDialog
    # TODO: tests for this property
    attr_reader :state

    def initialize
      @actions = []
      @await_reply = []
      @parser = BasicParser.new
      @state = 'pending'
    end

    # TODO: test explicit start
    def start(connection)
      @connection = connection
      # TODO: guard @state == 'pending'
      # TODO: if resulting promse fails, QuitCommand and die
      future = add_action_group [ EhloCommand.new("client") ]
      @await_reply << [nil, InitCommand.new]
      @connection.on_data(&method(:read))
      future
    end

    def auth(user, pass)
      # TODO: Check capabilities when it arrives
      add_action_group [ PlainAuthCommnad.new(user, pass) ]
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
      future
    end

    def quit
      # TODO: set @state = 'dead' when future completed - with tests!
      add_action_group [ QuitCommand.new ]
    end

    def read(data)
      puts '<- ' + data
      @parser.receive(data) do |lines|
        p, action = @await_reply.pop
        begin
          res = action.receive lines
          p.fulfill(res) if !res.nil?
        rescue Sumpter::CommandException => e
          p.fail(e)
          # Remove all subsequent commands in this group as it has failed
          @actions.reject! { |cand, action| cand == p }
        end
        next_action if @state == 'pending' || @state == 'idle'
      end
    end

    private

    def add_action_group(group)
      p = Ione::Promise.new
      group.each do |action|
        @actions << [p, action]
      end
      next_action if @state == 'idle'
      p.future
    end

    def next_action
      return if @actions.empty?
      @state = 'running'
      p, action = @actions.shift
      action.generate { |data|
        puts '-> ' + data
        @connection.write data
      }
      @await_reply << [p, action]
      @state = 'idle' # TODO: Test for state
    end
  end
end

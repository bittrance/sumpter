require 'ione'
require "sumpter/commands"
require "sumpter/parser"

module Sumpter
  class DialogException < Exception
    def initialize(message)
      super
    end
  end

  class SMTPDialog
    attr_accessor :logger
    # TODO: tests for this property
    attr_reader :state

    def initialize(logger)
      @logger = logger

      @actions = []
      @await_reply = []
      @parser = BasicParser.new
      @state = 'pending'
      @capabilities = []
    end

    # TODO: test explicit start
    def start(connection)
      @connection = connection
      @await_reply << [nil, InitCommand.new]
      @connection.on_data(&method(:read))
      # TODO: guard @state == 'pending'
      # TODO: if resulting promse fails, QuitCommand and die
      @ready = add_action_group([ EhloCommand.new ])
      .then do |res|
        cmd, status, *caps = res
        @capabilities = caps
        res
      end
    end

    def quit
      # TODO: set @state = 'dead' when future completed - with tests!
      add_action_group [ QuitCommand.new ]
    end

    def perform_action(&action)
      # TODO: Guard state dead?
      # This is so that start will have populated capabilities
      @ready.then {
        group = *(action.call @capabilities)
        add_action_group group
      }
    end

    def read(data)
      @logger.debug('<- ' + data.chomp)
      @parser.receive(data) do |lines|
        p, action = @await_reply.shift
        begin
          res = action.receive lines
          p.fulfill(res) if !res.nil?
        rescue StandardError => e
          p.fail(e) if !p.future.completed?
          # Remove all subsequent commands in this group as it has failed
          @actions.reject! { |cand, action| cand == p }
        end
      end
      # @await_reply.empty? == no more pipelined commands pending
      next_action if @await_reply.empty? && (@state == 'pending' || @state == 'idle')
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
        @logger.debug('-> ' + data.chomp)
        @connection.write data
      }
      @await_reply << [p, action]
      next_action if @capabilities.include?('PIPELINING') && action.is_pipelining?
      @state = 'idle' # TODO: Test for state
    end
  end
end

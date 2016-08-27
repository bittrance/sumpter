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
      # TODO: it is polite to supply hostname/ip as client
      add_action_group([ EhloCommand.new("client") ])
      .then do |res|
        cmd, status, *caps = res
        @capabilities = caps
        res
      end
    end

    def auth(user, pass)
      p = @capabilities.index { |lmnt| /^auth[ =]/i.match lmnt }
      eligible = []
      if p
        match = /auth[ =](.*)/i.match @capabilities[p]
        methods = match[0].split(" ")
        eligible = ['PLAIN', 'LOGIN'].select { |lmnt| methods.index(lmnt) }
      end

      if eligible.empty?
        raise DialogException.new('No compatible auth method')
      end

      case eligible[0]
      when "LOGIN"
        login = [ LoginAuthCommand.new(user, pass) ] * 2
      when "PLAIN"
        login = [ PlainAuthCommand.new(user, pass) ]
      end
      add_action_group login
    end

    def send(from, to, payload)
      # TODO: Guard state dead?
      # start if @state == 'pending' # FIXME: This is a future!
      to = to.is_a?(String) ? [to] : to
      add_action_group [
        MailCommand.new(from),
        *to.map { |recipient| RcptCommand.new(recipient) },
        DataCommand.new,
        PayloadCommand.new(payload)
      ]
    end

    def quit
      # TODO: set @state = 'dead' when future completed - with tests!
      add_action_group [ QuitCommand.new ]
    end

    def read(data)
      @logger.debug('<- ' + data.chomp)
      @parser.receive(data) do |lines|
        p, action = @await_reply.shift
        begin
          res = action.receive lines
          p.fulfill(res) if !res.nil?
        rescue Sumpter::CommandException => e
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

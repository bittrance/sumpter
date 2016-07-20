require 'ione'

require "sumpter/dialog"
require "sumpter/version"

module Sumpter
  class Client
    def initialize(host, port)
      @host = host
      @port = port
      @reactor = Ione::Io::IoReactor.new
    end

    def start
      @reactor.start
      .then { @reactor.connect(@host, @port) }
      .then { |conn|
        @handler = SMTPDialog.new(conn)
        @handler.start
      }
      .map(self)
    end

    # TODO: Split sync/async clients
    def send(from, to, message)
      Ione::Future.await(@handler.send(from, to, message))
    end

    def stop
      @handler.quit.then {
        @reactor.stop
      }
    end
  end

  module_function

  def syncClient(host, port)
    client = Client.new(host, port)
    Ione::Future.await(client.start)
  end
end

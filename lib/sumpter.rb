require 'ione'

require "sumpter/dialog"
require "sumpter/version"

module Sumpter
  class AsyncClient
    def initialize(host, port)
      @host = host
      @port = port
      @reactor = Ione::Io::IoReactor.new
      @handler = SMTPDialog.new
    end

    def start
      @reactor.start
      .then { @reactor.connect(@host, @port) }
      .then { |conn| @handler.start(conn) }
      .map(self)
    end

    def send(from, to, message)
      @handler.send(from, to, message)
    end

    def stop
      @handler.quit.then {
        @reactor.stop
      }
    end
  end
  
  class SyncClient < AsyncClient
    def start
      Ione::Future.await(super)
    end
    
    def send(from, to, message)
      Ione::Future.await(super)
    end
  end

  module_function

  def asyncClient(host, port)
    client = AsyncClient.new(host, port)
    client.start
  end
  
  def syncClient(host, port)
    client = SyncClient.new(host, port)
    client.start
    client
  end
end

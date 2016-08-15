require 'ione'

require "sumpter/dialog"
require "sumpter/version"

module Sumpter
  class AsyncClient
    def initialize(host, port = nil, ssl = false)
      @options = {}
      
      if port.nil?
        port = !ssl.nil? ? 465 : 25
      end
      
      if ssl
        if !ssl.is_a OpenSSL::SSL::SSLContext
          ssl = OpenSSL::SSL::SSLContext.new
          ssl.verify_mode = OpenSSL::SSL::VERIFY_PEER
        end
        if ssl.cert_store.nil?
          ssl.cert_store = OpenSSL::X509::Store.new
          ssl.cert_store.set_default_paths
        end
        @options[:ssl] = ssl
      end
      
      @host = host
      @port = port
      @reactor = Ione::Io::IoReactor.new
      @handler = SMTPDialog.new
    end

    def start
      @reactor.start
      .then { @reactor.connect(@host, @port, @options) }
      .then { |conn| @handler.start(conn) }
      .map(self)
    end

    def auth(username, password)
      @handler.auth(username, password)
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

    def auth(username, password)
      Ione::Future.await(super)
    end

    def send(from, to, message)
      Ione::Future.await(super)
    end
  end

  module_function

  def asyncClient(host, port, username = nil, password = nil)
    client = AsyncClient.new(host, port)
    client.start
    .then {
      client.auth(username, password) if validate_credentials(username, password)
    }
    .map(client)
  end

  def syncClient(host, port, username = nil, password = nil)
    client = SyncClient.new(host, port)
    client.start
    client.auth(username, password) if validate_credentials(username, password)
    client
  end

  private_class_method

  def validate_credentials(username, password)
    if username.nil? ^ password.nil?
      raise Exception.new("Expect username/password, got #{username}/#{password}")
    end
  end
end

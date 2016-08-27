require 'ione'

require "sumpter/dialog"
require "sumpter/version"

module Sumpter
  # Asynchronous SMTP client.
  #
  # All methods that interacts with the server return futures that
  # either completes with a parsed response from the server or fails
  #  with an exception.
  #
  # A fulfillment will have the form [command, response_code, *response_lines]
  # A failure will have an exception. Assuming the failure is not
  # internal to the lib it will be a FailureResponse, which indicates
  # that the server sent a 4XX or 5XX respinse code. The response can
  # be inspected in the exception's @response attribute.
  # A comprehensive example:
  # @example
  #   client = Sumpter::AsyncClient.new('smtp.gmail.com', ssl=true)
  #   client.start
  #   .then {
  #     f1 = client.auth('you@gmail.com', 'secret')
  #     f2 = client.send('someone@example.com', 'you@gmail.com', mail)
  #     Ione::Future.all(f1, f2)
  #   }
  #   .then {
  #     puts 'success'
  #   }
  class AsyncClient
    # @param [String] host Hostname where SMTP server resides.
    # @param [int] port Port number where SMTP server resides. Defaults to 25 for unencrypted connections and 465 for TLS-based connections.
    # @param Either true for dwfault TLS or an SSLContext object.
    def initialize(host, port = nil, ssl = false)
      @options = {}

      if port.nil?
        port = !ssl.nil? ? 465 : 25
      end

      if ssl
        if !ssl.is_a? OpenSSL::SSL::SSLContext
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

    # Connect to SMTP server and handshake.
    #
    # Returns a future thatbcompletes on successful connection and
    # handshake. Currently, this operation must complete before you
    # can continue using AsyncClient instance. In the future, this
    # limitation will be removed.
    def start
      @reactor.start
      .then { @reactor.connect(@host, @port, @options) }
      .then { |conn| @handler.start(conn) }
      .map(self)
    end

    # Authenticate with server.
    #
    # Returns a future that completes on successful autjentication.
    # Currently, PLAIN and LOGIN methods are supported, using
    # username/password credentials.
    def auth(username, password)
      @handler.auth(username, password)
    end

    # Send a message with envelope sender and recipient(s) as given.
    def send(from, to, message)
      @handler.send(from, to, message)
    end

    def stop
      @handler.quit
      .then { @reactor.stop }
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

    def stop
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
    !username.nil?
  end
end

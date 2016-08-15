require 'ione'
require 'observer'

class FakeServer
  include Observable

  attr_reader :port

  def initialize(handler_class = BaseSMTPHandler)
    @host = 'localhost'
    @port = 0
    @reactor = Ione::Io::IoReactor.new
    @handler_class = handler_class
  end

  def start
    if @reactor.running?
      raise Exception "Already started"
    end
    f = @reactor.start
    f = f.flat_map do
      @reactor.bind(@host, @port, 5) do |pending|
        pending.on_accept do |conn|
          handler = @handler_class.new(conn, self.notify_observers)
          handler.greet
        end
      end
    end
  end
end

class BaseSMTPHandler
  NEWLINE = "\r\n"
  DOT = "\r\n.\r\n"

  # "transition-from" matrix
  @states = {
    :quit => [ [nil, :mail, :rcpt, :data], NEWLINE, nil ],
    :helo => [ [nil, :mail, :rcpt, :data], NEWLINE, nil ],
    :mail => [ [:helo, :rcpt, :data], NEWLINE, [501, "Expecting HELO"] ],
    :rcpt => [ [:mail, :data], NEWLINE, [501, ""] ],
    :data => [ [:rcpt], DOT, [501, ""] ],
  }

  def initialize(conn, listener)
    @conn = conn
    @conn.on_data(&method(:_receive))
    @current_state = nil
    @separator = NEWLINE
    @staging = {}
    @listener = listener
    @buffer = ''
  end

  def _receive(data)
    @buffer << data
    while newline_index = @buffer.index(@separator)
      line = @buffer.slice!(0, newline_index + 1)
      cmd, argline = line.split(/w+/, 1)

      candidate = cmd.downcase.to_sym
      transition_from, @separator, failwith = @states[candidate]
      unless transition_from.contains? @current_state
        self._reply(*failwith)
        next
      end
      @current_state = candidate

      self.send(candidate, args)
    end
  end

  def _reply(code, message)
    @conn.write("#{code} #{message}\n")
    @conn.drain
  end

  def greet(argline)
    self._reply(220, @host)
  end

  def helo(argline)
    self._reply(250, @host)
  end

  def mail(argline)
    @staging[:mail] = argline
    self._reply(250, "Sender OK")
  end

  def rcpt(argline)
    return self._reply(500, "") if @staging[:mail]
    @staging[:rcpt] << argline
    self._reply(250, "Recipient OK")
  end

  def quit(ignored)
    self._reply(221, "Bye")
  end

  def data(argline)
    self._reply(354, "End data with <CR><LF>.<CR><LF>")
  end

  def receive_payload(payload)
    @staging[:payload] = payload
    @listener.call(@staging.clone)
    # TODO: how much do we need to purge from staging?
    self._reply(250, "Received")
  end

  def method_missing(name, *args)
    self.error line
  end
end

f = FakeServer.new
f.start

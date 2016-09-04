# require 'spec_helper'
require 'ione'
require 'logger'
require 'sumpter/dialog'

class MockConnection
  def initialize
    @answer = ''
  end

  def on_data
  end

  def write(data)
    @answer << data
  end

  def get_answer
    tmp = @answer
    @answer = ''
    tmp
  end
end

logger = Logger.new STDOUT

describe Sumpter::SMTPDialog do
  def await_timeout(f)
    timeout = @r.schedule_timer(0.01).map('timeout')
    Ione::Future.await(Ione::Future.first(f, timeout))
  end

  before(:all) do
    @r = Ione::Io::IoReactor.new
    Ione::Future.await(@r.start)
  end

  subject do
    described_class.new logger
  end

  it 'should be async and startable' do
    conn = MockConnection.new
    ready = subject.start conn
    subject.read "220 testscript\r\n"
    expect(conn.get_answer).to match(/ehlo.*/i)
    subject.read "250 mail.example.com.\r\n"
    cmd, *result = await_timeout(ready)
    expect(result).to eq([250, "mail.example.com."])
  end

  it 'should queue groups until it is properly started' do
    seen = []
    noop = Sumpter::NoopCommand.new
    conn = MockConnection.new
    f1 = subject.start conn
    f2 = subject.perform_action { |capabilities|
      seen += capabilities
      [noop]
    }

    subject.read "220 testscript\r\n"
    expect(conn.get_answer).to match(/ehlo.*/i)
    subject.read "250-STARTTLS\r\n250 mail.example.com\r\n"
    await_timeout f1
    subject.read "250 Ok\r\n"
    result = await_timeout f2

    expect(result).to eq([noop, 250, 'Ok'])
    expect(seen).to include('STARTTLS')
  end

  class BadGenerateCommand < Sumpter::NoopCommand
    def generate
      raise 'Bad developer!'
    end
  end

  it 'should propagate exceptions from commands generate' do
    conn = MockConnection.new
    f1 = subject.start conn
    f2 = subject.perform_action { BadGenerateCommand.new }
    subject.read "220 testscript\r\n"
    expect(conn.get_answer).to match(/ehlo.*/i)
    subject.read "250-STARTTLS\r\n250 mail.example.com\r\n"
    await_timeout f1
    expect(f2.failed?).to be(true)
  end

  class BadReceiveCommand < Sumpter::NoopCommand
    def receive(line)
      raise 'Bad developer!'
    end
  end

  it 'should propagate exceptions from commands receive' do
    conn = MockConnection.new
    f1 = subject.start conn
    f2 = subject.perform_action  { BadReceiveCommand.new }
    subject.read "220 testscript\r\n"
    expect(conn.get_answer).to match(/ehlo.*/i)
    subject.read "250-STARTTLS\r\n250 mail.example.com\r\n"
    await_timeout f1
    expect(f2.failed?).to be(false)
    subject.read "250 Ok\r\n"
    expect(f2.failed?).to be(true)
  end
end

# require 'spec_helper'
require 'smtpclient'

describe BasicParser do
  it 'should parse singleline replies' do
    parser = BasicParser.new
    parsed = []
    parser.receive("250 Some explanation\r\n") { |line| parsed << line }
    expect(parsed).to eq([["250", "Some explanation"]])
  end

  it 'should parse code only' do
    parser = BasicParser.new
    parsed = []
    parser.receive("250\r\n") { |line| parsed << line }
    expect(parsed).to eq([["250", '']])
  end

  it 'should parse fragments' do
    parser = BasicParser.new
    parsed = []
    parser.receive("250 Some ex") { |line| parsed << line }
    parser.receive("planation\r\n") { |line| parsed << line }
    expect(parsed).to eq([["250", "Some explanation"]])
  end

  it 'should parse multiline replies' do
    parser = BasicParser.new
    parsed = []
    parser.receive("250-mail.example.com.\r\n250-") { |line| parsed << line }
    parser.receive("PIPELINING\r\n250 ENHANCEDSTATUSCODES\r\n") { |line| parsed << line }
    expect(parsed).to eq([
    [ "250", "mail.example.com.", "PIPELINING", "ENHANCEDSTATUSCODES" ]
    ])
  end
end

describe 'ClientCommands' do

  describe 'commands' do
    it 'ehlo' do
      ehlo = EhloCommand.new "my-hostname"
      ehlo.promise = Ione::Promise.new
      command = ''
      ehlo.generate { |line| command << line }
      expect(ehlo.promise.future.resolved?).to be(false)
      expect(command).to eq("EHLO my-hostname\r\n")
      ehlo.receive ["250", "mail.example.com.", "PIPELINING"]
      expect(ehlo.promise.future.resolved?).to be(true)
      expect(ehlo.promise.future.value).to eq(['mail.example.com.', 'PIPELINING'])
    end

    it 'mail from' do
      mail = MailCommand.new "user@here.example.com"
      command = ''
      mail.generate { |line| command << line }
      expect(command).to eq("MAIL FROM:<user@here.example.com>\r\n")
    end

    it 'rcpt to' do
      rcpt = RcptCommand.new "user@there.exapmle.com"
      command = ''
      rcpt.generate { |line| command << line }
      expect(command).to eq("RCPT TO:<user@there.exapmle.com>\r\n")
    end

    it 'data' do
      data = DataCommand.new
      command = ''
      data.generate { |line| command << line }
      expect(command).to eq("DATA\r\n")
    end

    it 'payload' do
      zemime = StringIO.new("A payload")
      payload = PayloadCommand.new zemime
      command = ''
      payload.generate { |line| command << line }
      expect(command).to eq("A payload\r\n.\r\n")
    end

    it 'quit' do
      quit = QuitCommand.new
      command = ''
      quit.generate { |line| command << line }
      expect(command).to eq("QUIT\r\n")
    end
  end

  it 'has a version number' do
    expect(Smtpclient::VERSION).not_to be nil
  end
end

describe 'SmtpClient' do
  it 'should provide synchronous clients' do
    client = SmtpClient.syncClient('localhost', 25)
    res = client.send('from@me.com', 'quest@waiwai.windwards.net', StringIO.new('message'))
    expect(res).to eq(true) # indicates success for now
    client.stop
  end
end

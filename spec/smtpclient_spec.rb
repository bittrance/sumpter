# require 'spec_helper'
require 'smtpclient'

describe 'ClientCommands' do
  describe BasicParser do
    it 'should parse singleline replies' do
      parser = BasicParser.new
      parsed = parser.receive "250 Some explanation\r\n"
      expect(parsed).to eq(["250", "Some explanation"])
    end

    it 'should parse multiline replies' do
      parser = BasicParser.new
      parsed = parser.receive "250-mail.example.com.\r\n250-PIPELINING\r\n250 ENHANCEDSTATUSCODES\r\n"
      expect(parsed).to eq(
        [ "250", "mail.example.com.", "PIPELINING", "ENHANCEDSTATUSCODES" ]
      )
    end
  end

  describe 'commands' do
    it 'ehlo' do
      ehlo = EhloCommand.new "my-hostname"
      command = ''
      ehlo.generate { |line| command << line }
      expect(command).to eq("EHLO my-hostname\r\n")
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

    it 'should refuse to send payloads that are known to be too large' do

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

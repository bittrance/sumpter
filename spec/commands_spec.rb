require 'sumpter'

describe 'commands' do
  it 'ehlo' do
    ehlo = Sumpter::EhloCommand.new "my-hostname"
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
    mail = Sumpter::MailCommand.new "user@here.example.com"
    command = ''
    mail.generate { |line| command << line }
    expect(command).to eq("MAIL FROM:<user@here.example.com>\r\n")
  end

  it 'rcpt to' do
    rcpt = Sumpter::RcptCommand.new "user@there.exapmle.com"
    command = ''
    rcpt.generate { |line| command << line }
    expect(command).to eq("RCPT TO:<user@there.exapmle.com>\r\n")
  end

  it 'data' do
    data = Sumpter::DataCommand.new
    command = ''
    data.generate { |line| command << line }
    expect(command).to eq("DATA\r\n")
  end

  it 'payload' do
    zemime = StringIO.new("A payload")
    payload = Sumpter::PayloadCommand.new zemime
    command = ''
    payload.generate { |line| command << line }
    expect(command).to eq("A payload\r\n.\r\n")
  end

  it 'quit' do
    quit = Sumpter::QuitCommand.new
    command = ''
    quit.generate { |line| command << line }
    expect(command).to eq("QUIT\r\n")
  end
end

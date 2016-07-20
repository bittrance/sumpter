require 'ione'
require 'sumpter/commands'

describe 'commands' do
  it 'ehlo' do
    ehlo = Sumpter::EhloCommand.new "my-hostname"
    ehlo.promise = Ione::Promise.new
    command = ''
    ehlo.generate { |line| command << line }
    expect(ehlo.promise.future.resolved?).to be(false)
    expect(command).to eq("EHLO my-hostname\r\n")
    ehlo.receive [250, "mail.example.com.", "PIPELINING"]
    expect(ehlo.promise.future.resolved?).to be(true)
    expect(ehlo.promise.future.value).to eq([ehlo, 250, 'mail.example.com.', 'PIPELINING'])
  end

  it 'mail from succeeds' do
    mail = Sumpter::MailCommand.new "user@here.example.com"
    mail.promise = Ione::Promise.new
    command = ''
    mail.generate { |line| command << line }
    expect(command).to eq("MAIL FROM:<user@here.example.com>\r\n")
    mail.receive [250, "OK"]
    expect(mail.promise.future.resolved?).to be(false) # Only PayloadCommand is expected to resolve
  end
  
  it 'mail from fails properly' do
    mail = Sumpter::MailCommand.new "user@here.example.com"
    mail.promise = Ione::Promise.new
    mail.receive [521, "You suck"]
    expect(mail.promise.future.failed?).to be(true)
    expect{ mail.promise.future.value }.to raise_exception Sumpter::CommandException    
  end

  it 'rcpt to succeed' do
    rcpt = Sumpter::RcptCommand.new "user@there.exapmle.com"
    rcpt.promise = Ione::Promise.new
    command = ''
    rcpt.generate { |line| command << line }
    expect(command).to eq("RCPT TO:<user@there.exapmle.com>\r\n")
    rcpt.receive [250, 'OK']
    expect(rcpt.promise.future.resolved?).to be(false) # Only PayloadCommand is expected to resolve
  end

  it 'rcpt to fails properly' do
    rcpt = Sumpter::RcptCommand.new "user@there.exapmle.com"
    rcpt.promise = Ione::Promise.new
    rcpt.receive [521, 'You suck']
    expect(rcpt.promise.future.failed?).to be(true)
    expect { rcpt.promise.future.value }.to raise_exception Sumpter::CommandException      
  end

  it 'data succeeds' do
    data = Sumpter::DataCommand.new
    data.promise = Ione::Promise.new
    command = ''
    data.generate { |line| command << line }
    expect(command).to eq("DATA\r\n")
    data.receive([354, ''])
    expect(data.promise.future.resolved?).to be(false) # Only PayloadCommand is expected to resolve
  end

  it 'payload succeeds' do
    zemime = StringIO.new("A payload")
    payload = Sumpter::PayloadCommand.new zemime
    payload.promise = Ione::Promise.new
    command = ''
    payload.generate { |line| command << line }
    expect(command).to eq("A payload\r\n.\r\n")
    payload.receive [250, 'Thx']
    expect(payload.promise.future.completed?).to eq(true)
    expect(payload.promise.future.value).to eq([payload, 250, 'Thx'])
  end

  it 'payload fails properly' do
    zemime = StringIO.new("A payload")
    payload = Sumpter::PayloadCommand.new zemime
    payload.promise = Ione::Promise.new
    payload.receive [521, 'Dont want it']
    expect(payload.promise.future.completed?).to eq(true)
    expect{ payload.promise.future.value }.to raise_exception Sumpter::CommandException
  end

  it 'quit succeeds' do
    quit = Sumpter::QuitCommand.new
    quit.promise = Ione::Promise.new
    command = ''
    quit.generate { |line| command << line }
    expect(command).to eq("QUIT\r\n")
    quit.receive [221, 'Please come again']
    expect(quit.promise.future.completed?).to eq(true)
    expect(quit.promise.future.value).to eq([quit, 221, 'Please come again'])
  end
end

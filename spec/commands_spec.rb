require 'ione'
require 'sumpter/commands'

describe 'commands' do
  it 'ehlo' do
    ehlo = Sumpter::EhloCommand.new "my-hostname"
    command = ''
    ehlo.generate { |line| command << line }
    expect(command).to eq("EHLO my-hostname\r\n")
    res = ehlo.receive [250, "mail.example.com.", "PIPELINING"]
    expect(res).to eq([ehlo, 250, 'mail.example.com.', 'PIPELINING'])
  end

  it 'mail from succeeds' do
    mail = Sumpter::MailCommand.new "user@here.example.com"
    command = ''
    mail.generate { |line| command << line }
    expect(command).to eq("MAIL FROM:<user@here.example.com>\r\n")
    mail.receive [250, "OK"] # No exploding, plz
  end

  it 'mail from fails properly' do
    mail = Sumpter::MailCommand.new "user@here.example.com"
    expect{ mail.receive [521, "You suck"] }.to raise_exception Sumpter::CommandException
  end

  it 'rcpt to succeed' do
    rcpt = Sumpter::RcptCommand.new "user@there.exapmle.com"
    command = ''
    rcpt.generate { |line| command << line }
    expect(command).to eq("RCPT TO:<user@there.exapmle.com>\r\n")
    rcpt.receive [250, 'OK']
  end

  it 'rcpt to fails properly' do
    rcpt = Sumpter::RcptCommand.new "user@there.exapmle.com"
    expect { rcpt.receive [521, 'You suck'] }.to raise_exception Sumpter::CommandException
  end

  it 'data succeeds' do
    data = Sumpter::DataCommand.new
    command = ''
    data.generate { |line| command << line }
    expect(command).to eq("DATA\r\n")
    data.receive([354, ''])
  end

  it 'payload succeeds' do
    zemime = StringIO.new("A payload")
    payload = Sumpter::PayloadCommand.new zemime
    command = ''
    payload.generate { |line| command << line }
    expect(command).to eq("A payload\r\n.\r\n")
    res = payload.receive [250, 'Thx']
    expect(res).to eq([payload, 250, 'Thx'])
  end

  it 'payload fails properly' do
    zemime = StringIO.new("A payload")
    payload = Sumpter::PayloadCommand.new zemime
    expect{ payload.receive [521, 'Dont want it'] }.to raise_exception Sumpter::CommandException
  end

  it 'quit succeeds' do
    quit = Sumpter::QuitCommand.new
    command = ''
    quit.generate { |line| command << line }
    expect(command).to eq("QUIT\r\n")
    res = quit.receive [221, 'Please come again']
    expect(res).to eq([quit, 221, 'Please come again'])
  end
end

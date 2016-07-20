require 'sumpter'

describe Sumpter::BasicParser do
  it 'should parse singleline replies' do
    parser = Sumpter::BasicParser.new
    parsed = []
    parser.receive("250 Some explanation\r\n") { |line| parsed << line }
    expect(parsed).to eq([[250, "Some explanation"]])
  end

  it 'should parse code only' do
    parser = Sumpter::BasicParser.new
    parsed = []
    parser.receive("250\r\n") { |line| parsed << line }
    expect(parsed).to eq([[250, '']])
  end

  it 'should parse fragments' do
    parser = Sumpter::BasicParser.new
    parsed = []
    parser.receive("250 Some ex") { |line| parsed << line }
    parser.receive("planation\r\n") { |line| parsed << line }
    expect(parsed).to eq([[250, "Some explanation"]])
  end

  it 'should parse multiline replies' do
    parser = Sumpter::BasicParser.new
    parsed = []
    parser.receive("250-mail.example.com.\r\n250-") { |line| parsed << line }
    parser.receive("PIPELINING\r\n250 ENHANCEDSTATUSCODES\r\n") { |line| parsed << line }
    expect(parsed).to eq([
    [ 250, "mail.example.com.", "PIPELINING", "ENHANCEDSTATUSCODES" ]
    ])
  end
end

describe Sumpter do
  it 'should provide synchronous clients' do
    client = Sumpter::syncClient('localhost', 25)
    res = client.send('from@me.com', 'quest@whiskers', StringIO.new('message'))
    expect(res[1]).to eq(250) # indicates success for now
    client.stop
  end
end

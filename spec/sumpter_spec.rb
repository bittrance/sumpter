require 'sumpter'

describe Sumpter do
  it 'should provide synchronous clients' do
    client = Sumpter::syncClient('localhost', 25)
    res = client.send('from@me.com', 'quest@whiskers', StringIO.new('message'))
    expect(res[1]).to eq(250) # indicates success for now
    client.stop
  end
end

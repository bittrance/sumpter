require 'ione'
require 'sumpter'

describe Sumpter do
  it 'should provide asynchronous clients' do
    f = Sumpter::asyncClient('localhost', 25)
    client = Ione::Future.await(f)
    f = client.send('from@me.com', 'quest@waiwai.windwards.net', StringIO.new('message'))
    res = Ione::Future.await(f)
    expect(res[1]).to eq(250) # indicates success for now
    client.stop
  end

  it 'should provide synchronous clients' do
    client = Sumpter::syncClient('localhost', 25)
    res = client.send('from@me.com', 'quest@waiwai.windwards.net', StringIO.new('message'))
    expect(res[1]).to eq(250) # indicates success for now
    client.stop
  end
end

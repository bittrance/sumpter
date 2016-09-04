require 'ione'
require 'sumpter'

describe Sumpter do
  it 'should provide asynchronous clients' do
    f = Sumpter::asyncClient('localhost', 25)
    client = Ione::Future.await(f)
    f = client.mail(StringIO.new('message'), 'from@me.com', 'quest@waiwai.windwards.net')
    res = Ione::Future.await(f)
    expect(res[1]).to eq(250) # indicates success for now
    client.stop
  end

  it 'should provide an asynchronous client that is authenticated' do
    f = Sumpter::asyncClient('localhost', 25, 'quest@windwards.net', 'Jordgubb')
    client = Ione::Future.await(f)
    f = client.mail(StringIO.new('message'), 'from@me.com', 'quest@waiwai.windwards.net')
    res = Ione::Future.await(f)
    expect(res[1]).to eq(250) # indicates success for now
    client.stop
  end

  it 'should provide synchronous clients' do
    client = Sumpter::syncClient('localhost', 25)
    res = client.mail(StringIO.new('message'), 'from@me.com', 'quest@waiwai.windwards.net')
    expect(res[1]).to eq(250) # indicates success for now
    client.stop
  end

  it 'should provide a synchronous client that is authenticated' do
    client = Sumpter::syncClient('localhost', 25, 'quest@windwards.net', 'Jordgubb')
    res = client.mail(StringIO.new('message'), 'from@me.com', 'quest@waiwai.windwards.net')
    expect(res[1]).to eq(250) # indicates success for now
    client.stop
  end
end

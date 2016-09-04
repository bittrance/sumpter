require 'sumpter/actions'

describe Sumpter::Actions do
  class MockDialog
    attr_reader :commands
    def initialize(capabilities)
      @capabilities = capabilities
      @commands = []
    end
    def perform_action(&block)
      @commands += [*block.call(@capabilities)]
    end
  end

  class ActionsUser
    attr_reader :handler

    def initialize(capabilities = [])
      @handler = MockDialog.new(capabilities)
      extend Sumpter::Actions
    end
  end


  it 'should select preferred login method login' do
    subject = ActionsUser.new(['AUTH LOGIN PLAIN'])
    subject.auth('user', 'pass')
    result = *subject.handler.commands
    expect(result[0].class).to be(Sumpter::LoginAuthCommand)
  end

  it 'should select preferred login method plain' do
    subject = ActionsUser.new(['AUTH PLAIN LOGIN'])
    subject.auth('user', 'pass')
    result = *subject.handler.commands
    expect(result[0].class).to be(Sumpter::PlainAuthCommand)
  end

  it 'should select preferred login method plain' do
    subject = ActionsUser.new(['AUTH FOOBAR'])
    expect { subject.auth('user', 'pass') }.to raise_exception(Sumpter::DialogException)
  end

  it 'should generate send actions' do
    subject = ActionsUser.new
    subject.mail(StringIO.new('message'), 'from@me.com', 'to@you.com', 'cc@them.com')
    result = subject.handler.commands
    expect(result.size).to eq(5)
    expect(result[1].class).to be(Sumpter::RcptCommand)
    expect(result[2].class).to be(Sumpter::RcptCommand)
  end
end

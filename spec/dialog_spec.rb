# require 'spec_helper'
require 'ione'
require 'sumpter'

class MockConnection
  def initialize
    @answer = ''
  end

  def on_data
  end

  def write(data)
    @answer << data
  end

  def get_answer
    tmp = @answer
    @answer = ''
    tmp
  end
end

describe Sumpter::SendMail do
  it 'should be async and startable' do
    conn = MockConnection.new
    actor = Sumpter::SendMail.new(conn)
    r = Ione::Io::IoReactor.new
    f = r.start
    f = f.then do
      ready = actor.start
      actor.read "220 testscript\r\n"
      expect(conn.get_answer).to match(/ehlo.*/i)
      actor.read "250 mail.example.com.\r\n"

      timeout = r.schedule_timer(0.01).map('timeout')
      Ione::Future.first(ready, timeout)
    end
    f.on_failure { |err| puts err }

    cmd, *result = f.value
    expect(result).to eq([250, "mail.example.com."])
  end

  # TODO: test that proves we can accept send before start is done

end

describe 'dialog' do
  cases = [
    {
      desc: 'simple input, no pipelining',
      sendargs: [
        ['from@me.com', 'to@you.com', StringIO.new('message')]
      ],
      dialog: [
        ["220 testscript\r\n", /ehlo client/i],
        ["250 mailserver.example.com.\r\n", /mail.*<from@me.com>/i],
        ["250 OK\r\n", /rcpt.*<to@you.com>/i],
        ["250 OK\r\n", /data/i],
        ["354\r\n", /message/i],
        ["250 queued as XYZ\r\n", nil]
      ]
    },
    {
      desc: 'two consecutive mail input, no pipelining',
      sendargs: [
        ['from@me.com', 'to@you.com', StringIO.new('message1')],
        ['from@me.com', 'to@alterego.com', StringIO.new('message2')]
      ],
      dialog: [
        ["220 testscript\r\n", /ehlo client/i],
        ["250 mailserver.example.com.\r\n", /mail.*<from@me.com>/i],
        ["250 OK\r\n", /rcpt.*<to@you.com>/i],
        ["250 OK\r\n", /data/i],
        ["354\r\n", /message/i],
        ["250 queued as XYZ\r\n", /mail.*<from@me.com>/i],
        ["250 OK\r\n", /rcpt.*<to@alterego.com>/i],
        ["250 OK\r\n", /data/i],
        ["354\r\n", /message/i],
        ["250\r\n", nil]
      ]
    },
    # {
    #   desc: 'pipelining, two recipients',
    #   sendargs: [
    #     ['from@me.com', ['to@you.com', 'cc@you.com'], StringIO.new('message')],
    #   ],
    #   dialog: [
    #     ["220 testscript\r\n", /ehlo client/i],
    #     ["250-PIPELINING\r\n250 mailserver.example.com.\r\n",
    #       /mail.*from@me.example.com.*rcpt.*to@you.example.com.*cc@you.example.com.*data/i],
    #     ["250 OK\r\n250 OK\r\n 250 OK\r\n354\r\n", /message.*quit/i],
    #     ["250 OK\r\n250 Bye\r\n", nil]
    #   ]
    # },
    #
    # # Error cases below
    #
    # {
    #   desc: 'invalid from address',
    #   sendargs: [
    #     ['@', 'to@you.com', StringIO.new('message')]
    #   ],
    #   dialog: [
    #     ["220 testscript\r\n", /ehlo client/i],
    #     ["250 mailserver.example.com.\r\n", /mail from.*/i],
    #     ["501 Bad sender\r\n", nil]
    #   ]
    # },
    # {
    #   desc: 'invalid from address followed by well-formatted send',
    #   sendargs: [
    #     ['@', 'to@you.com', StringIO.new('message')],
    #     ['from@me.com', 'to@you.com', StringIO.new('message1')]
    #   ],
    #   dialog: [
    #     ["220 testscript\r\n", /ehlo client/i],
    #     ["250 mailserver.example.com.\r\n", /mail from.*/i],
    #     ["501 Bad sender\r\n", /mail.*<from@me.com>/i], # crap, let's try next message
    #     ["250 OK\r\n", /rcpt.*<to@alterego.com>/i],
    #     ["250 OK\r\n", /data/i],
    #     ["354\r\n", /message/i],
    #     ["250\r\n", nil]
    #   ]
    # }

  ]

  def assert_dialog(conn, actor, dialog)
    dialog.each do |input, output|
      actor.read input if input
      answer = conn.get_answer
      expect(answer).to eq('') unless output
      expect(answer).to match(output) if output
    end
  end

  cases.each do |onecase|
    it 'should handle ' + onecase[:desc] do
      conn = MockConnection.new
      actor = Sumpter::SendMail.new(conn)
      actor.start
      futures = []
      onecase[:sendargs].each do |args|
        futures << actor.send(*args)
      end
      assert_dialog(conn, actor, onecase[:dialog])

      # Check the returned futures
      unfinished = futures.any? { |future| !future.completed? }
      expect(unfinished).to eq(false)
      values = futures.map { |future| future.value }
      #expect(values).to eq(onecase[:returns])
    end
  end

  it 'should handle spaced sends' do
    conn = MockConnection.new
    actor = Sumpter::SendMail.new(conn)
    actor.start
    actor.send('from@me.com', 'to@you.com', StringIO.new('message1'))
    assert_dialog(conn, actor, [
      ["220 testscript\r\n", /ehlo client/i],
      ["250 mailserver.example.com.\r\n", /mail.*<from@me.com>/i],
      ["250 OK\r\n", /rcpt.*<to@you.com>/i],
      ["250 OK\r\n", /data/i],
      ["354\r\n", /message/i],
      ["250 queued as XYZ\r\n", nil],
    ])
    actor.send('from@me.com', 'to@alterego.com', StringIO.new('message2'))
    assert_dialog(conn, actor, [
      [nil, /mail.*<from@me.com>/i],
      ["250 OK\r\n", /rcpt.*<to@alterego.com>/i],
      ["250 OK\r\n", /data/i],
      ["354\r\n", /message/i],
      ["250\r\n", nil]
    ])
  end
end

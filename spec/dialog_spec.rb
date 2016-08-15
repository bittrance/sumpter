# require 'spec_helper'
require 'ione'
require 'sumpter/dialog'

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

describe Sumpter::SMTPDialog do
  it 'should be async and startable' do
    actor = Sumpter::SMTPDialog.new
    r = Ione::Io::IoReactor.new
    conn = MockConnection.new
    f = r.start
    f = f.then do
      ready = actor.start conn
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
      calls: [
        ['send', 'from@me.com', 'to@you.com', StringIO.new('message')]
      ],
      returns: [true],
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
      calls: [
        ['send', 'from@me.com', 'to@you.com', StringIO.new('message1')],
        ['send', 'from@me.com', 'to@alterego.com', StringIO.new('message2')]
      ],
      returns: [true, true],
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
    {
      desc: 'pipelining, two recipients',
      calls: [
        ['send', 'from@me.com', ['to@you.com', 'cc@you.com'], StringIO.new('message')],
      ],
      returns: [true],
      dialog: [
        ["220 testscript\r\n", /ehlo client/i],
        ["250-PIPELINING\r\n250 mailserver.example.com.\r\n",
          /mail.*from@me.com.*rcpt.*to@you.com.*cc@you.com.*data/im],
        ["250 OK\r\n250 OK\r\n250 OK\r\n354\r\n", /message/i],
        ["250 OK\r\n", nil]
      ]
    },
    # Test infrastructure can't test this right now
    # {
    #   desc: 'authenticating with login when recommended',
    #   calls: [
    #     ['auth', 'username', 'password']
    #   ],
    #   returns: [true],
    #   dialog: [
    #     ["220 testscript\r\n", /ehlo client/i],
    #     ["250 AUTH LOGIN\r\n", /auth login dXNlcm5hbWU=/im],
    #     ["334 UGFzc3dvcmQ6\r\n", /cGFzc3dvcmQ=/i],
    #     ["235 successful\r\n", nil]
    #   ]
    # },
    #
    # # Error cases below
    #
    {
      desc: 'invalid from address',
      calls: [
        ['send', '@', 'to@you.com', StringIO.new('message')]
      ],
      returns: [false],
      dialog: [
        ["220 testscript\r\n", /ehlo client/i],
        ["250 mailserver.example.com.\r\n", /mail from.*/i],
        ["501 Bad sender\r\n", nil]
      ]
    },
    {
      desc: 'pipelining, bad sender',
      calls: [
        ['send', '@', 'to@you.com', StringIO.new('message')],
      ],
      returns: [false],
      dialog: [
        ["220 testscript\r\n", /ehlo client/i],
        ["250-PIPELINING\r\n250 mailserver.example.com.\r\n",
          /mail.*rcpt.*to@you.com.*data/im],
        ["501 Bad sender\r\n550 No sender\r\n550 Not ready\r\n", nil]
      ]
    },

    # {
    #   desc: 'invalid from address followed by well-formatted send',
    #   calls: [
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
      actor = Sumpter::SMTPDialog.new
      conn = MockConnection.new
      futures = []
      actor.start conn
      onecase[:calls].each do |call, *args|
        case call
        when 'auth'
          futures << actor.auth(*args)
        when 'send'
          futures << actor.send(*args)
        end
      end
      assert_dialog(conn, actor, onecase[:dialog])

      # Check the returned futures
      unfinished = futures.any? { |future| !future.completed? }
      expect(unfinished).to eq(false)
      futures.zip(onecase[:returns]).each do |future, expected|
        expect(future.resolved?).to eq(expected)
      end
    end
  end

  it 'should handle spaced sends' do
    actor = Sumpter::SMTPDialog.new
    conn = MockConnection.new
    actor.start conn
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

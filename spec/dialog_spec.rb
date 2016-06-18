# require 'spec_helper'
require 'smtpclient'

describe 'dialog' do
  cases = [
    {
      desc: 'simple input, no pipelining',
      actor: SendMail.new('from@me.example.com', 'to@you.example.com', StringIO.new('message')),
      dialog: [
        ["220 testscript\r\n", /ehlo client/i],
        ["250 mailserver.example.com.\r\n", /mail.*<from@me.example.com>/i],
        ["250 OK\r\n", /rcpt.*<to@you.example.com>/i],
        ["250 OK\r\n", /data/i],
        ["354\r\n", /message/i],
        ["250\r\n", /quit/i]
      ]
    },
    # {
    #   desc: 'pipelining, two recipients',
    #   actor: SendMail.new('from@me.example.com', ['to@you.example.com', 'cc@you.example.com'], StringIO.new('message')),
    #   dialog: [
    #     ["220 testscript", /ehlo client/i],
    #     ["250-PIPELINING\r\n250 mailserver.example.com.\r\n",
    #       /mail.*from@me.example.com.*rcpt.*to@you.example.com.*cc@you.example.com.*data/i],
    #     ["250 OK\r\n250 OK\r\n 250 OK\r\n354\r\n", /message.*quit/i],
    #     ["250 OK\r\n250 Bye\r\n", nil]
    #   ]
    # }
  ]

  cases.each do |onecase|
    it 'should manage ' + onecase[:desc] do
      onecase[:dialog].each do |input, output|
        answer = onecase[:actor].read input
        expect(answer).to match(output)
      end
    end
  end
end

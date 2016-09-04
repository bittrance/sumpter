require 'sumpter/commands'
require 'sumpter/dialog'

module Sumpter
  module Actions
    # TODO: Grow mapping of login methods=>commands; solve when we implement a non-u/p method
    def auth(user, pass)
      @handler.perform_action { |capabilities|
        p = capabilities.index { |lmnt| /^auth[ =]/i.match lmnt }
        eligible = []
        if p
          match = /auth[ =](.*)/i.match capabilities[p]
          methods = match[0].split(" ")
          eligible = methods.select { |lmnt| ['PLAIN', 'LOGIN'].include?(lmnt.upcase) }
        end

        if eligible.empty?
          raise DialogException.new('No compatible auth method')
        end

        case eligible[0]
        when "LOGIN"
          [ LoginAuthCommand.new(user, pass) ] * 2
        when "PLAIN"
          PlainAuthCommand.new(user, pass)
        end
      }
    end

    def mail(payload, from, *to)
      @handler.perform_action { |capabilities|
        [
          MailCommand.new(from),
          *to.map { |recipient| RcptCommand.new(recipient) },
          DataCommand.new,
          PayloadCommand.new(payload)
        ]
      }
    end
  end
end

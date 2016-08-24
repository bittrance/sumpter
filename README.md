# Sumpter

Sumpter is an asynchronous SMTP client geared towards high-volume mail sending and various advanced use cases, where you need detailed control over the SMTP dialog.

Sumpter depends on [Ione](https://github.com/iconara/ione) for its non-blocking action. Its future implementation will impact your code.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sumpter'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sumpter

## Usage

Sumpter provides both blocking and non-blocking interfaces. The simplest possible case:

```ruby
client = Sumpter.syncClient('localhost', 25)
client.send('me@example.com', 'you@example.com', ...)
client.stop
```

A typical asynchronous use case. Note that Google require the account to be putt in 'less secure apps' mode for password access to work.

```ruby
require 'sumpter'
require 'ione'
require 'mime'

me = 'me@gmail.com'

msg = MIME::Mail.new
msg.subject = 'This is important'
msg.body = MIME::Text.new('hello, world!', 'plain', 'charset' => 'us-ascii')
msg.from = me
msg.to = 'list@example.com'

client = Sumpter::AsyncClient.new('smtp.google.com', 465, ssl = true)
client.start
.then {
  client.auth(me, 'secret')
}
.then {
  Ione::Future.all(
    client.send(me, '', msg.to_s),
    client.send(me, '', msg.to_s),
    client.send(me, '', msg.to_s)
  )
}
.then { |results|
  puts 'Results: ' + results
}
```
There are many ways you can customize the SMTP dialog to your use case.

As can be seen from the above example, each send operation (or indeed any operation against the server) will fulfill with an array:

- command instance that failed or succeeded
- response code
- zero or more elements (normally one) representing the lines the server sent

In particular, the send() method will execute more than one command against the server, so in order to programmatically know which one failed, you could

```ruby
cmd, code, *lines = result

case cmd.?
when Sumpter::MailCommand
  puts "Sender #{cmd.sender} was not appreciated."
when Sumpter::RcptCommand
  puts "Recipient #{cmd.recipient} was not appreciated"
when Sumpter::DataCommand
  pute "Failed data command with #{lines[0]}"
when Sumpter::PayloadCommand
end

Some actions may contain multiple commands and in order to know which one failed, 

```ruby
class NonFailingRcptCommand < RcptCommand
  def initiate(rejects, to)
    super(to)
    @rejects = rejects
  end
  
  def receive(line)
    if line[0] >= 400
      @rejects << [@to, *line]
    end
  end
end

class MyStrategy < BaseStrategy
  def send(from, to, mail)
    rejects = []
    return [ 
      MailCommand.new(from),
      *to.each { |one| NonFailingRcptCommand.new(rejects, one) },
      DataCommand.new,
      PayloadCommand.new(mail)
    ]
  end
end
```

Note how we are reusing the standard commands for all the bits we don't want to change.

## Implementation

Sumpter is implemented as a queue of SMTP commands that are processed against the server connection one at a time. Each command is an instance of a command object that is first asked to generate a string (e.g. "EHLO me.example.com") and then receives a parsed server response.

## Development

TODO: write help

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/bittrance/sumpter.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

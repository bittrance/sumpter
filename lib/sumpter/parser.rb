module Sumpter
  class BasicParser
    def initialize
      @buffer = ''
      @line_re = /^(?<code>[0-9]+)(?<sep>[- ]?)(?<message>.*)$/
      @reply = []
    end

    def receive(data)
      @buffer << data
      while newline_index = @buffer.index("\r\n")
        line = @buffer.slice!(0, newline_index + 1)
        line.chomp!
        res = @line_re.match(line)
        @reply << res[:message]
        if res[:sep] == ' ' or res[:sep] == ''
          yield [res[:code].to_i] + @reply
          @reply.clear
        end
      end
    end
  end
end
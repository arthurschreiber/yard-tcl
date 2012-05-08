class Command
  attr_accessor :line_no
  attr_accessor :char_no
  attr_accessor :words
  attr_accessor :comments

  def initialize(line_no, char_no)
    @line_no, @char_no = line_no, char_no
    @words = []
    @comments = []
  end
end

class Comment
  attr_accessor :line_no
  attr_accessor :char_no
  attr_accessor :text

  def initialize(line_no, char_no)
    @line_no, @char_no = line_no, char_no
  end
end

class UnquotedWord
  attr_accessor :parts

  def initialize(line_no, char_no)
    @line_no, @char_no = line_no, char_no
    @parts = []
  end

  def simple?
    @parts.none? { |part| part.is_a?(CommandSubstitution) || part.is_a?(VariableSubstitution) }
  end
end

class CommandSubstitution < String
end

class VariableSubstitution < String
end

class TclParser
  TYPE_NORMAL       = 0x0
  TYPE_SPACE        = 0x1
  TYPE_COMMAND_END  = 0x2
  TYPE_SUBS         = 0x4
  TYPE_QUOTE        = 0x8
  TYPE_CLOSE_PAREN  = 0x10
  TYPE_CLOSE_BRACK  = 0x20
  TYPE_BRACE        = 0x40

  CHAR_TYPE       = Hash.new { |h, k| h[k] = TYPE_NORMAL }

  CHAR_TYPE["\\"] = TYPE_SUBS
  CHAR_TYPE["$"]  = TYPE_SUBS
  CHAR_TYPE["["]  = TYPE_SUBS

  CHAR_TYPE[";"]  = TYPE_COMMAND_END
  CHAR_TYPE["\n"] = TYPE_COMMAND_END

  CHAR_TYPE["\t"] = TYPE_SPACE
  CHAR_TYPE["\v"] = TYPE_SPACE
  CHAR_TYPE["\f"] = TYPE_SPACE
  CHAR_TYPE["\r"] = TYPE_SPACE
  CHAR_TYPE[" "]  = TYPE_SPACE

  CHAR_TYPE[")"]  = TYPE_CLOSE_PAREN

  CHAR_TYPE["\""] = TYPE_QUOTE

  CHAR_TYPE["{"]  = TYPE_BRACE
  CHAR_TYPE["}"]  = TYPE_BRACE

  def initialize(source, file = '(stdin)')
    @source = source
    @file = file
    @tokens = []

    # Index of the last newline char
    @last_newline = 0
    @size = @source.size
    @index = 0
    @line_no = 1

    @tokens = []
  end

  def char_no
    @index - @last_newline
  end

  def line_no
    @line_no
  end

  def parse_command
    command = Command.new(char_no, line_no)
    command.comments = parse_comments

    while true
      consume_whitespace

      if !(@index < @size)
        break
      end

      if @source[@index] == '"'
        parse_quoted_string
      elsif @source[@index] == "{"
        parse_braces
      else
        command.words << parse_unquoted_word
      end

      if consume_whitespace > 0
        next
      end

      if !(@index < @size)
        break
      end

      if (CHAR_TYPE[@source[@index]] & TYPE_COMMAND_END) != 0
        break
      else

      end
    end

    command.words.size > 0 ? command : nil
  end

  def parse_unquoted_word
    word = UnquotedWord.new(char_no, line_no)

    while @index < @size && ((type = CHAR_TYPE[@source[@index]]) & (TYPE_SPACE | TYPE_COMMAND_END) == 0)
      start = @index

      if (type & TYPE_SUBS) == 0
        while @index < @size && (@index += 1) && ((CHAR_TYPE[@source[@index]] & (TYPE_SPACE | TYPE_COMMAND_END | TYPE_SUBS)) == 0)
        end

        word.parts << @source[start...@index]
      elsif @source[@index] == "$"
        raise "Variables not supported yet!"
      end
    end

    word
  end

  # def parse_quoted_string
  #   @index += 1
  #   parse_tokens(TYPE_QUOTE)

  #   if @source[@index] != '"'
  #     raise 'missing \"'
  #   end

  #   @index += 1
  # end

  # def parse_tokens(stop_mask)
  #   while @index < @size && ((type = CHAR_TYPE[@source[@index]]) & stop_mask) == 0
  #     start = @index
  #     start_char_no = char_no
  #     start_line_no = line_no

  #     if type & TYPE_SUBS == 0
  #       while @index < @size && (@index += 1) && ((CHAR_TYPE[@source[@index]] & (stop_mask | TYPE_SUBS)) == 0)
  #       end

  #       token = TextToken.new(start_line_no, start_char_no)
  #       token.text = @source[start...@index]
  #       tokens << token
  #     elsif @source[@index] == "$"
  #       parse_varname
  #     end
  #   end
  # end

  # def parse_varname
  #   start = @index
  #   start_char_no = char_no
  #   start_line_no = line_no

  #   @index += 1

  #   while @index < @size
  #     case @source[@index]
  #     when "A".."Z", "a".."z", "0".."9", "_"
  #       @index += 1
  #     when ":"
  #       if @source[@index+1] == ":"
  #         @index += 2
  #         @index += 1 while @source[@index] == ":"
  #       else
  #         break
  #       end
  #     else
  #       break
  #     end
  #   end

  #   if start+1 == @index
  #     token = TextToken.new(start_line_no, start_char_no)
  #   else
  #     token = VariableToken.new(start_line_no, start_char_no)
  #   end

  #   token.text = @source[start...@index]
  #   @tokens << token
  # end

  # Parses comments as defined by Tcl's rules.
  # @return [Array<CommentNode>] the parsed CommentNode
  def parse_comments
    comments = []

    while @index < @size
      begin
        consume_whitespace
      end while @index < @size && @source[@index] == "\n" && @last_newline = @index && @index += 1 and @line_no += 1

      if !(@index < @size) || @source[@index] != "#"
        break
      end

      start = @index

      comment = Comment.new(line_no, char_no)

      while @index < @size
        @index += 1
        if @source[@index] == "\n"
          break
        end
      end

      comment.text = @source[start..@index]
      comments << comment
    end

    return comments
  end

  # Consumes whitespace and returns the number of characters consumed
  def consume_whitespace
    start = @index

    while @index < @size
      while true
        case @source[@index]
        when "\t", "\v", "\f", "\r", " "
          @index += 1
        else
          break
        end
      end

      if @source[@index] != "\\"
        break
      end

      if (@index + 1) == @size
        break
      end

      if @source[@index+1] != "\n"
        break
      end

      @index += 2
      @line_no += 1

      if !(@index < @size)
        raise "incomplete parse"
      end
    end

    @index - start
  end
end
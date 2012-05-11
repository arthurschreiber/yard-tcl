require 'ffi'

module YARD
  module Parser
    module Tcl

      module FFI
        extend ::FFI::Library

        ffi_lib "tcl"

        class Token < ::FFI::Struct
          WORD        = 1
          SIMPLE_WORD = 2
          TEXT        = 4
          BS          = 8
          COMMAND     = 16
          VARIABLE    = 32
          SUB_EXPR    = 64
          OPERATOR    = 128
          EXPAND_WORD = 256

          layout({
            # Type of token, such as TCL_TOKEN_WORD
            :type => :int,

            # A String starting at the first character in the token
            :start => :pointer,

            # Number of bytes in the token
            :size => :int,

            # Number of subtokens in this token
            :numComponents => :int
          })

          def content
            self[:start].read_string(self[:size])
          end
        end

        class Parse < ::FFI::Struct
          SUCCESS           = 0
          QUOTE_EXTRA       = 1
          BRACE_EXTRA       = 2
          MISSING_BRACE     = 3
          MISSING_BRACKET   = 4
          MISSING_PAREN     = 5
          MISSING_QUOTE     = 6
          MISSING_VAR_BRACE = 7
          SYNTAX            = 8
          BAD_NUMBER        = 9

          layout({
            :commentStart    => :pointer,
            :commentSize     => :int,
            :commandStart    => :pointer,
            :commandSize     => :int,
            :numWords        => :int,
            :tokenPtr        => :pointer,
            :numTokens       => :int,
            :tokensAvailable => :int,
            :errorType       => :int,
            :string          => :pointer,
            :end             => :pointer,
            :interp          => :pointer,
            :term            => :pointer,
            :incomplete      => :int,
            :staticTokens    => [Token, 20]
          })

          def command
            self[:commandStart].read_string(self[:commandSize])
          end

          def comments
            if self[:commentStart].address != 0
              self[:commentStart].read_string(self[:commentSize]).to_s.gsub(/^\s*(\#+)\s{0,1}/, '')
            end
          end

          def tokens
            token_arr = ::FFI::Pointer.new(Tcl::FFI::Token, self[:tokenPtr])
            (0...self[:numTokens]).map do |i|
              FFI::Token.new(token_arr[i])
            end
          end
        end

        attach_function :parse_command, :Tcl_ParseCommand, [:pointer, :pointer, :int, :int, :pointer], :int
        attach_function :free_parse, :Tcl_FreeParse, [:pointer], :void
      end

      class Command < Array
        attr_reader :line_range
        attr_reader :comments_range
        attr_reader :comments

        def initialize(line, source, comments)
          @source = source
          @comments = (comments || "")

          @comments_range = (line..(line+@comments.count("\n")))
          @line_range = (@comments_range.last..(line+source.count("\n")))
        end

        # Tcl comments have no hash flag set
        def comments_hash_flag
          false
        end

        def source
          @source
        end

        def line
          @line_range.first
        end

        def first_line
          source.split(/\r?\n/).first.strip
        end

        def show
          "\t#{line}: #{first_line}"
        end

        def tokens=(tokens)
          line_no = @line_range.first

          while current = tokens.shift
            token = Token.for_type(current[:type]).new(current.content, line_no)
            line_no = token.line_range.last
            token.tokens = tokens.slice!(0, current[:numComponents])
            self << token
          end
        end
      end

      class Token < Array
        attr_reader :line_range

        def initialize(content, line)
          @content = content
          @line_range = (line..line+content.count("\n"))
        end

        def to_s
          @content
        end

        def tokens=(tokens)
          line_no = @line_range.first

          while current = tokens.shift
            token = Token.for_type(current[:type]).new(current.content, line_no)
            line_no = token.line_range.last
            token.tokens = tokens.slice!(0, current[:numComponents])
            self << token
          end
        end

        class << self
          def for_type(type)
            case type
            when FFI::Token::WORD
              WordToken
            when FFI::Token::SIMPLE_WORD
              SimpleWordToken
            when FFI::Token::TEXT
              TextToken
            when FFI::Token::BS
              BsToken
            when FFI::Token::COMMAND
              CommandToken
            when FFI::Token::VARIABLE
              VariableToken
            when FFI::Token::SUB_EXPR
              SubExprToken
            when FFI::Token::OPERATOR
              OperatorToken
            when FFI::Token::EXPAND_WORD
              ExpandWordToken
            end
          end
        end
      end

      class WordToken < Token
      end

      class SimpleWordToken < Token
      end

      class TextToken < Token
      end

      class BsToken < Token
      end

      class CommandToken < Token
      end

      class VariableToken < Token
      end

      class SubExprToken < Token
      end

      class OperatorToken < Token
      end

      class ExpandWordToken < Token
      end

      class TclParser < Parser::Base
        def initialize(source, file = '(stdin)')
          @source = source
          @file = file

          @commands = []
        end

        def parse(line_no = 1)
          parse = Tcl::FFI::Parse.new

          current_position = 0

          begin
            source_ptr = ::FFI::MemoryPointer.from_string(@source[current_position..-1])

            Tcl::FFI.parse_command(nil, source_ptr, -1, 0, parse)

            # First, count newlines between the last command and this one
            line_no += source_ptr.read_string(parse[:commandStart].address - source_ptr.address).count("\n") - 1

            if parse.command != ""
              command = Command.new(line_no, parse.command, parse.comments)
              command.tokens = parse.tokens

              line_no = command.line_range.last

              @commands << command
            end

            current_position += (parse[:commandStart].address - parse[:string].address) + parse[:commandSize]
          ensure
            Tcl::FFI.free_parse(parse)
          end until source_ptr == parse[:end]
        end

        def enumerator
          @commands
        end
      end

    end
  end
end
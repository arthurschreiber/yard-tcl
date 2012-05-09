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
              self[:commentStart].read_string(self[:commentSize]).to_s.gsub(/^(\#+)\s{0,1}/, '')
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

      class Command
        attr_accessor :tokens
        attr_reader :line
        attr_accessor :comments

        def initialize(content, line)
          @content = content
          @line = line
          @tokens = []
          @comments = ""
        end

        def comments_hash_flag
          false
        end

        def comments_range
          line
        end

        def show
          ""
        end
      end

      class Token
        attr_accessor :tokens

        def initialize(content)
          @content = content
          @tokens = []
        end

        def to_s
          @content
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

        def parse
          parse = Tcl::FFI::Parse.new
          source_ptr = ::FFI::MemoryPointer.from_string(@source)
          line_no = 1

          begin
            Tcl::FFI.parse_command(nil, source_ptr, -1, 0, parse)

            # First, count newlines between the last command and this one
            line_no += source_ptr.read_string(parse[:commandStart].address - source_ptr.address).count("\n")

            if parse.command != ""
              command = Command.new(parse.command, line_no)
              command.comments = parse.comments
              command.tokens = nest_tokens(parse.tokens)
              @commands << command
            end

            # Then, add newlines inside this command
            line_no += parse.command.count("\n")

            # Update the source pointer to point to the end of this command
            source_ptr = ::FFI::Pointer.new(parse[:commandStart].address + parse[:commandSize])
          end until source_ptr == parse[:end]
        end

        def nest_tokens(tokens)
          i = 0

          result = []

          while i < tokens.size
            token = Token.for_type(tokens[i][:type]).new(tokens[i].content)

            if tokens[i][:numComponents] > 0
              token.tokens = nest_tokens(tokens[i+1, tokens[i][:numComponents]])
              i += tokens[i][:numComponents] + 1
            else
              i += 1
            end

            result << token
          end

          result
        end

        def enumerator
          @commands
        end
      end

    end
  end
end
def __p(*path)
  File.join(File.dirname(__FILE__), *path)
end

module YARD
  module Parser
    module Tcl
      autoload :TclParser, __p("parser", "tcl", "tcl_parser")
    end

    SourceParser.register_parser_type :tcl, Tcl::TclParser, %w( tcl )
  end

  module Handlers
    module Tcl

      class Base < Handlers::Base
        class << self
          include Parser::Tcl

          def handles?(node)
            handlers.any? do |a_handler|
              node.class == a_handler
            end
          end
        end

        include Parser::Tcl

        def parse_block(word, opts = {})
          push_state(opts) do
            t = Parser::Tcl::TclParser.new(word.parts[0])
            t.line_no = word.line_no
            t.parse

            parser.process(t.enumerator)
          end
        end
      end

      class ProcHandler < Base
        handles Command

        process do
          if statement.words[0].parts[0] == "proc"
            register MethodObject.new(namespace, statement.words[1].parts[0])
          end
        end
      end

      class NamespaceHandler < Base
        handles Command

        process do
          if statement.words.length > 2
            if statement.words[0].parts[0] == "namespace" && statement.words[1].parts[0] == "eval"
              modname = statement.words[2].parts[0]
              mod = register ModuleObject.new(namespace, modname)
              parse_block(statement.words[3], :namespace => mod)
            end
          end
        end
      end
    end

    Processor.register_handler_namespace :tcl, Tcl
  end
end
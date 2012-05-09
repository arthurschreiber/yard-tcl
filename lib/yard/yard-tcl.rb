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

        def parse_block(block, opts = {})
          push_state(opts) do
            t = Parser::Tcl::TclParser.new(block)
            t.parse
            parser.process(t.enumerator)
          end
        end
      end

      class ProcHandler < Base
        handles Command

        process do
          begin
            if statement.tokens[0].tokens[0].to_s == "proc" && statement.tokens.size == 4 && statement.tokens[1].is_a?(SimpleWordToken)
              register MethodObject.new(namespace, statement.tokens[1].to_s)
            end

          rescue Exception => e
            p statement
            p e
          end
        end
      end

      class NamespaceHandler < Base
        handles Command

        process do
          if statement.tokens[0].to_s == "namespace" && statement.tokens[1].to_s == "eval"
            if statement.tokens.size >= 4 && statement.tokens[3].is_a?(SimpleWordToken)
              modname = statement.tokens[2].to_s
              mod = register ModuleObject.new(namespace, modname)

              statement.tokens[2..-1].each do |token|
                parse_block(token.tokens[0].to_s, :namespace => mod)
              end
            end
          end
        end
      end
    end

    Processor.register_handler_namespace :tcl, Tcl
  end
end
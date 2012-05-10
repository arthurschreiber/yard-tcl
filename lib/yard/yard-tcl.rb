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

        def parse_block(token, opts = {})
          push_state(opts) do
            t = Parser::Tcl::TclParser.new(token.to_s)
            t.parse(token.line_range.first)
            parser.process(t.enumerator)
          end
        end
      end

      class ProcHandler < Base
        handles Command

        process do
          if statement[0][0].to_s == "proc" && statement.size == 4 && statement[1].is_a?(SimpleWordToken)
            register MethodObject.new(namespace, statement[1].to_s)
          end
        end
      end

      class NamespaceHandler < Base
        handles Command

        process do
          if statement[0].to_s == "namespace" && statement[1].to_s == "eval"
            if statement.size >= 4 && statement[3].is_a?(SimpleWordToken)
              modname = statement[2].to_s
              mod = register ModuleObject.new(namespace, modname)

              statement[2..-1].each do |token|
                parse_block(token[0], :namespace => mod)
              end
            end
          end
        end
      end
    end

    Processor.register_handler_namespace :tcl, Tcl
  end
end
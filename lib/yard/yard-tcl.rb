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
      end

      class ProcHandler < Base
        handles Command

        process do
          begin
            if statement.words[0].parts[0] == "proc"
              register MethodObject.new(:root, statement.words[1].parts[0])
            end
          rescue => e
            puts e
          end
        end
      end
    end

    Processor.register_handler_namespace :tcl, Tcl
  end
end
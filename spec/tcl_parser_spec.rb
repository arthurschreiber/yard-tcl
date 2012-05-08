require "yard"
require "yard/parser/tcl/tcl_parser"

describe YARD::Parser::Tcl::TclParser do
  describe "parse_comments" do
    it "returns a list of parsed comment" do
      @parser = YARD::Parser::Tcl::TclParser.new("# This is a comment")
      comments = @parser.parse_comments

      comments.should have(1).item

      comments[0].line_no.should == 1
      comments[0].char_no.should == 0
      comments[0].text.should == "# This is a comment"
    end

    it "parses indented singe-line comments" do
      @parser = YARD::Parser::Tcl::TclParser.new("    # This is a comment")
      comments = @parser.parse_comments

      comments.should have(1).items

      comments[0].line_no.should == 1
      comments[0].char_no.should == 4
      comments[0].text.should == "# This is a comment"
    end

    it "parses multi-line comments" do
      @parser = YARD::Parser::Tcl::TclParser.new("# This is a comment\n# spanning multiple lines")
      comments = @parser.parse_comments

      comments.should have(2).items

      comments[0].line_no.should == 1
      comments[0].char_no.should == 0
      comments[0].text.should == "# This is a comment\n"

      comments[1].line_no.should == 2
      comments[1].char_no.should == 0
      comments[1].text.should == "# spanning multiple lines"
    end
  end

  describe "#parse_command" do
    it "parses and returns the next command from the source" do
      @parser = YARD::Parser::Tcl::TclParser.new("expr 1 + 2")
      command = @parser.parse_command

      command.should have(4).words
      command.words[0].parts.should == ["expr"]
      command.words[1].parts.should == ["1"]
      command.words[2].parts.should == ["+"]
      command.words[3].parts.should == ["2"]
    end

    it "returns nil if all commands have been parsed" do
      @parser = YARD::Parser::Tcl::TclParser.new("expr 1 + 2\nproc something\n")
      @parser.parse_command.should_not be_nil
      @parser.parse_command.should_not be_nil
      @parser.parse_command.should be_nil
    end

    it "assigns any preceding comments to the command" do
      @parser = YARD::Parser::Tcl::TclParser.new("# Add 1 to 2\nexpr 1 + 2\n# Define a proc\nproc something\n")
      command = @parser.parse_command
      command.should have(1).comments
      command.comments[0].text.should == "# Add 1 to 2\n"

      command = @parser.parse_command
      command.should have(1).comments
      command.comments[0].text.should == "# Define a proc\n"
    end

    it "correctly parses braced words" do
      @parser = YARD::Parser::Tcl::TclParser.new("namespace eval SomeNamespace {}")
      command = @parser.parse_command
      command.should have(4).words
    end
  end

  describe "#parse_braces" do
    it "parses a braced word" do
      @parser = YARD::Parser::Tcl::TclParser.new("{ hello world }")
      word = @parser.parse_braces

      word.should be_a(YARD::Parser::Tcl::BracedWord)
      word.should have(1).parts
      word.parts[0].should == " hello world "
    end

    it "parses an empty braced word" do
      @parser = YARD::Parser::Tcl::TclParser.new("{}")
      word = @parser.parse_braces

      word.should be_a(YARD::Parser::Tcl::BracedWord)
      word.should have(1).parts
      word.parts[0].should == ""
    end

    it "correctly handles braced words with newlines" do
      @parser = YARD::Parser::Tcl::TclParser.new("{\n  hello\n  world\n}")
      word = @parser.parse_braces

      word.should be_a(YARD::Parser::Tcl::BracedWord)
      word.should have(1).parts
      word.parts[0].should == "\n  hello\n  world\n"
    end
  end
end
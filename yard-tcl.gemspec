SPEC = Gem::Specification.new do |s|
  s.name          = "yard-tcl"
  s.summary       = "YARD plugin to generate documentation for Tcl source code"
  s.license       = 'MIT'
  s.version       = "0.0.1"
  s.date          = "2012-05-10"
  s.author        = "Arthur Schreiber"
  s.email         = "schreiber.arthur+yard-tcl@googlemail.com"
  s.homepage      = "http://nokarma.org/yard-tcl/"
  s.platform      = Gem::Platform::RUBY
  s.files         = Dir.glob("lib/**/*") + ['MIT-LICENSE', 'README.md']
  s.require_paths = ['lib']
  s.has_rdoc      = 'yard'
  s.add_dependency 'yard', '~> 0.8.1'
end
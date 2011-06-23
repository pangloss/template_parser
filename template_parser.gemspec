# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "template_parser/version"

Gem::Specification.new do |s|
  s.name        = "template_parser"
  s.version     = TemplateParser::VERSION
  s.authors     = ["Darrick Wiebe"]
  s.email       = ["darrick@innatesoftware.com"]
  s.homepage    = "https://github.com/pangloss/template_parser"
  s.summary     = %q{Parse text files by example}
  s.description = %q{When you need to parse crazy oldschool ascii reports from mainframes or legacy applications of all sorts, this tool can make it quite easy and keep your code concise and maintainable.}

  s.rubyforge_project = "template_parser"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end

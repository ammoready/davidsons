# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "davidsons/version"

Gem::Specification.new do |spec|
  spec.name          = "davidsons"
  spec.version       = Davidsons::VERSION
  spec.authors       = ["David Knight"]
  spec.email         = ["viacoffee@gmail.com"]

  spec.summary       = %q{Ruby library for Davidson's}
  spec.description   = %q{}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "savon", "~> 2.11.1"

  spec.add_runtime_dependency "smarter_csv", "~> 1.1.4"

  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "activesupport", "~> 5"
end

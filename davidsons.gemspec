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

  spec.add_dependency "savon"

  spec.add_runtime_dependency "smarter_csv"
  spec.add_runtime_dependency "net-ftp"
  spec.add_runtime_dependency "net-sftp"
  spec.add_runtime_dependency "csv"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "activesupport"
end

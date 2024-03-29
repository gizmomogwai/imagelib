# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'imagelib/version'

Gem::Specification.new do |spec|
  spec.name          = "imagelib"
  spec.version       = Imagelib::VERSION
  spec.authors       = ["Christian Köstlin"]
  spec.email         = ["christian.koestlin@esrlabs.com"]
  spec.description   = %q{gem to support my photo workflow}
  spec.summary       = %q{gem to support my photo workflow}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "ruby-progressbar"
  spec.add_dependency 'ffi'
  spec.add_dependency 'exifr'
  spec.add_dependency 'colorize'
  spec.add_dependency 'faraday_middleware'
  spec.add_dependency 'byebug'
  spec.add_dependency 'dnssd'
  spec.add_dependency 'addressable'
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
end

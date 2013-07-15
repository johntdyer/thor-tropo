# -*- encoding: utf-8 -*-
require File.expand_path('../lib/thor-tropo/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["John Dyer"]
  gem.email         = ["johntdyer@gmail.com"]
  gem.description   = %q{Thor tasks to package a project}
  gem.summary       = %q{Set of tasks to assist in making packages from a git controlled project.}
  gem.homepage      = "https://github.com/johntdyer/thor-tropo"

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "thor-tropo"
  gem.require_paths = ["lib","bin"]
  gem.version       = ThorTropo::VERSION

  gem.add_dependency 'json', ">= 1.7.0"
  gem.add_dependency 'thor'
  gem.add_dependency 'chef', "~> 11.0"
  gem.add_dependency 'berkshelf'
  gem.add_dependency 'thor-scmversion'
  gem.add_dependency 'minitar',           '~> 0.5.4'
  gem.add_dependency 'aws-sdk'
  gem.add_dependency 'fog'

  gem.add_development_dependency 'foodcritic'
  gem.add_development_dependency 'webmock'
  gem.add_development_dependency 'spork'
  gem.add_development_dependency 'simplecov'
  gem.add_development_dependency 'vcr'
  gem.add_development_dependency 'aruba'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency "bundler", "~> 1.3"
  gem.add_development_dependency "rake"
end

# encoding: utf-8
$:.unshift File.expand_path('../lib', __FILE__)

require 'bundler'
require 'thor/rake_compat'
require 'thor/scmversion'
require 'thor-tropo'
class Gem < Thor
  include Thor::RakeCompat
  Bundler::GemHelper.install_tasks

  desc 'build', "Build thor-tropo-#{ThorTropo::VERSION}.gem into the pkg directory"
  def build
    Rake::Task['build'].execute
  end

  desc 'install', "Build and install thor-tropo-#{ThorTropo::VERSION}.gem into system gems"
  def install
    Rake::Task['install'].execute
  end

  desc 'release', "Create tag v#{ThorTropo::VERSION} and build and push thor-tropo-#{ThorTropo::VERSION}.gem to Rubygems"
  def release
    Rake::Task['release'].execute
  end
end

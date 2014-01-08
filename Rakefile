require 'bundler'  
require 'rspec/core/rake_task'

# Bundler::GemHelper.install_tasks 

RSpec::Core::RakeTask.new(:spec)

desc "Run unit tests"
RSpec::Core::RakeTask.new('spec:unit') { |t| t.pattern = "./spec/unit/**/*_spec.rb" }

desc 'Default task which runs all specs'
task :default => 'spec:unit'

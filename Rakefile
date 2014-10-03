require 'bundler'
require 'rspec/core/rake_task'

LIB_DIR = File.join(File.dirname(__FILE__), 'lib')
$LOAD_PATH << LIB_DIR
require 'sitediff/util/webserver'

PORT = 13080

task :default => :tests

desc 'Run all tests'
task :tests => [:spec, 'fixture:spec']

# TODO should we expose prof.html as an argument?
desc 'Profile sitediff'
task :profile do
  rp_opts = [
    "-E '$LOAD_PATH << \"#{LIB_DIR}\"'", # since $0 won't be bin/sitediff
    "-f prof.html",
    "-p graph_html"
  ]

  paths = '/tmp/paths'
  File.write(paths, "/\n")

  # TODO: More useful config
  sd_opts = [
    "--before-url=http://google.com",
    "--after-url=http://google.ca",
    "--paths-from-file=#{paths}"
  ]

  sh "ruby-prof #{rp_opts.join(' ')} bin/sitediff -- diff #{sd_opts.join(' ')}"

  rm paths
end

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = './spec/unit/**/*_spec.rb'
end

desc 'Serve the output directory of sitediff'
task :serve, [:port, :dir] do |t, args|
  SiteDiff::Util::Webserver.serve(
    args[:port] || PORT, args[:dir] || 'output').wait
end

namespace :fixture do
  CMD = ['./bin/sitediff', 'diff', 'spec/fixtures/config.yaml']

  desc 'Run a sitediff test case'
  task :local do
    sh *CMD
  end

  desc 'Run a sitediff test case, using web servers'
  task :served do
    SiteDiff::Util::FixtureServer.new do |f|
      sh *CMD, '--before', f.before, '--after', f.after
    end
  end

  desc 'Check that the test case works'
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.pattern = './spec/fixtures/*_spec.rb'
  end
end

namespace :docker do
  IMAGE = "evolvingweb/sitediff"

  desc 'Build a docker container for sitediff'
  task :build do
    sh 'docker', 'build', '-t', IMAGE, '.'
  end

  desc 'Run a rake task (or a shell if empty) inside docker'
  task :run, [:task] do |t, args|
    opts = ['-v', "#{Dir.pwd}:/sitediff", '-t']
    if tsk = args[:task]
      cmd = ['rake', tsk]
    else
      opts += ['-i']
      cmd = ['bash']
    end
    sh 'docker', 'run', *opts, IMAGE, *cmd
  end
end

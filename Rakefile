require 'bundler'
require 'rspec/core/rake_task'

LIB_DIR = File.join(File.dirname(__FILE__), 'lib')
$LOAD_PATH << LIB_DIR
require 'sitediff/util/webserver'

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


def serve(port, dir, announce = false)
  port ||= SiteDiff::Util::Webserver::DEFAULT_PORT
  SiteDiff::Util::Webserver.serve(port, dir, :announce => announce)
end

def http_fixtures
  serv = SiteDiff::Util::FixtureServer.new
  sh *CMD, '--before', serv.before, '--after', serv.after
  return serv
end

namespace :fixture do
  CMD = ['./bin/sitediff', 'diff', 'spec/fixtures/config.yaml']

  desc 'Run a sitediff test case'
  task :local do
    sh *CMD
  end

  desc 'Run a sitediff test case, using web servers'
  task :served do
    http_fixtures.kill
  end

  desc 'Serve the result of the fixture test'
  task :serve do
    http_fixtures
    SiteDiff::Util::Webserver.serve(nil, 'output', :announce => true,
      :quiet => true).wait
  end

  desc 'Check that the test case works'
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.pattern = './spec/fixtures/*_spec.rb'
  end
end

# FIXME add a test to run spec on the installed gem inside docker container
namespace :docker do
  IMAGE = "evolvingweb/sitediff"

  desc 'Build a docker container for sitediff'
  task :build do
    sh 'docker', 'build', '-t', IMAGE, '.'
  end

  desc 'Run a rake task (or a shell if empty) inside docker'
  task :run, [:task] do |t, args|
    opts = ['-v', "#{File.dirname(__FILE__)}:/sitediff", '-t']
    if tsk = args[:task]
      cmd = ['bundle', 'exec', 'rake', tsk]
    else
      opts += ['-i']
      cmd = ['bash']
    end
    sh 'docker', 'run', *opts, IMAGE, *cmd
  end
end

#!/usr/bin/env ruby

LIB_DIR = File.join(File.dirname(__FILE__), 'lib')
$LOAD_PATH << LIB_DIR
require 'sitediff/util/webserver'

class Base < Thor
  # gives us run()
  include Thor::Actions

  # Thor, by default, exits with 0 no matter what!
  def self.exit_on_failure?
    true
  end

  private
  def sitediff(global=false)
    global ? 'sitediff' : './bin/sitediff'
  end

  def thor(global=false)
    global ? 'thor' : 'bundle exec thor'
  end
end

class Docker < Base
  IMAGE = 'evolvingweb/sitediff'

  desc 'build', 'Build a docker image for sitediff'
  def build
    run "docker build -t #{IMAGE} . "
  end

  # NOTE We can't override run() (which is reserved by Thor). Luckily, Thor only
  # checks for the first N necessary characters to match a command with a
  # method. Cf. Thor::normalize_command_name()
  option 'global',
    :type => :boolean,
    :default => false,
    :desc => 'Runs installed gems instead of `bundle exec`'
  desc 'run', 'Run a rake task (or a login shell if none given) inside docker'
  def run_(task='bash')
    if task == 'bash'
      cmd = 'bash'
    else
      opt = (options['global']) ? '--global' : ''
      cmd = "#{thor(options['global'])} #{task} #{opt}"
    end
    run "docker run -t -v #{File.dirname(__FILE__)}:/sitediff #{IMAGE} #{cmd}"
  end
end

class Spec < Base
  desc 'unit', 'RSpec tests'
  def unit
    run "rspec spec/unit"
  end
  default_task :unit
end

class Fixture < Base
  option 'global',
    :type => :boolean,
    :default => false,
    :desc => 'Runs installed gems instead of `bundle exec`'
  desc 'local', 'Run a sitediff test case'
  def local
    run "#{sitediff(options['global'])} diff spec/fixtures/config.yaml"
  end

  option 'global',
    :type => :boolean,
    :default => false,
    :desc => 'Runs installed gems instead of `bundle exec`'
  desc 'http', 'Run a sitediff test case, using web servers'
  def http
    cmd = "#{sitediff(options['global'])} diff spec/fixtures/config.yaml"
    http_fixtures(cmd).kill
  end

  option 'global',
    :type => :boolean,
    :default => false,
    :desc => 'Runs installed gems instead of `bundle exec`'
  desc 'serve', 'Serve the result of the fixture test'
  def serve
    cmd = "#{sitediff(options['global'])} diff spec/fixtures/config.yaml"
    http_fixtures(cmd)
    SiteDiff::Util::Webserver.serve(nil, 'output', :announce => true,
      :quiet => true).wait
  end

  desc 'spec', 'Check that the test case works'
  def spec
    run "rspec spec/fixtures"
  end

  private
  def serve(port, dir, announce = false)
    port ||= SiteDiff::Util::Webserver::DEFAULT_PORT
    SiteDiff::Util::Webserver.serve(port, dir, :announce => announce)
  end

  def http_fixtures(cmd)
    serv = SiteDiff::Util::FixtureServer.new
    run "#{cmd} --before #{serv.before} --after #{serv.after}"
    return serv
  end
end

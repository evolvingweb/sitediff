#!/usr/bin/env ruby

LIB_DIR = File.join(File.dirname(__FILE__), 'lib')
$LOAD_PATH << LIB_DIR
require 'sitediff/webserver'
require 'sitediff/webserver/resultserver'

class Base < Thor
  # adds the option to all Base subclasses
  # method_options() takes different arguments than option()
  method_options :local => true
  def initialize(*args)
    super(*args)
    @local = options['local']
  end

  # gives us run()
  include Thor::Actions

  # Thor, by default, exits with 0 no matter what!
  def self.exit_on_failure?
    true
  end

  protected
  def executable(gem)
    gem = './bin/sitediff' if gem == 'sitediff' and @local
    "#{'bundle exec' if @local} #{gem}"
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
  desc 'run', 'Run a rake task (or a login shell if none given) inside docker'
  def run_(task='bash')
    docker_opts = ["-t", "-v #{File.dirname(__FILE__)}:/sitediff"]
    if task == 'bash'
      cmd = 'bash'
      docker_opts << '-i'
    else
      # pass down the local flag to docker command
      cmd = "#{executable('thor')} #{task} #{@local ? '--local' : '--no-local'}"
    end
    run "docker run #{docker_opts.join(' ')} #{IMAGE} #{cmd}"
  end
end

class Spec < Base
  desc 'unit', 'run RSpec unit tests'
  def unit
    run "#{executable('rspec')} spec/unit"
  end

  desc 'fixture', 'run RSpec integration tests'
  def fixture
    run "#{executable('rspec')} spec/fixtures"
  end

  # hidden task to lump together multiple tasks
  desc 'all', 'runs both unit and fixture tests', :hide => true
  def all
    unit
    fixture
  end
  default_task :all

end

class Fixture < Base
  desc 'local', 'Run a sitediff test case'
  def local
    run "#{executable('sitediff')} diff spec/fixtures/config.yaml"
  end

  desc 'http', 'Run a sitediff test case, using web servers'
  def http
    cmd = "#{executable('sitediff')} diff spec/fixtures/config.yaml"
    http_fixtures(cmd).kill
  end

  desc 'serve', 'Serve the result of the fixture test'
  def serve
    cmd = "#{executable('sitediff')} diff spec/fixtures/config.yaml"
    http_fixtures(cmd)
    SiteDiff::Webserver::ResultServer.new(nil, 'output', :quiet => true).wait
  end

  private

  def http_fixtures(cmd)
    serv = SiteDiff::Webserver::FixtureServer.new
    run "#{cmd} --before #{serv.before} --after #{serv.after}"
    return serv
  end
end

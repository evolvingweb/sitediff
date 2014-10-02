require 'bundler'
require 'rspec/core/rake_task'

LIB_DIR = File.join(File.dirname(__FILE__), 'lib')

task :default => :spec

# TODO should we expose prof.html as an argument?
task :profile do
  rp_opts = [
    "-E '$LOAD_PATH << \"#{LIB_DIR}\"'", # since $0 won't be bin/sitediff
    "-f prof.html",
    "-p graph_html"
  ]

  paths = '/tmp/paths'
  File.write(paths, "/\n")

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

namespace :fixture do
  PORT = 13080
  CMD = ['./bin/sitediff', 'diff', 'spec/fixtures/config.yaml']

  task :local do
    sh *CMD
  end
  task :served do
    threads = []
    urls = []
    %w[before after].each_with_index do |dir, i|
      port = PORT + i
      threads << webserver(port, File.join('spec/fixtures', dir))
      urls << "http://localhost:#{port}"
    end
    sh *CMD, '--before', urls.first, '--after', urls.last
    threads.each { |t| t.kill }
  end
end

namespace :docker do
  IMAGE = "evolvingweb/sitediff"

  task :build do
    sh 'docker', 'build', '-t', IMAGE, '.'
  end

  task :run, [:task] do |t, args|
    opts = ['-v', "#{Dir.pwd}:/sitediff", '-t']
    if tsk = args[:task]
      cmd = ['rake', tsk]
    else
      opts = ['-i']
      cmd = ['bash']
    end
    sh 'docker', 'run', *opts, IMAGE, *cmd
  end
end

# Start a web server, return a thread
def webserver(port, dir)
  require 'webrick'
  w = WEBrick::HTTPServer.new(
    :Port => port,
    :DocumentRoot => dir,
    # Make it quiet!
    :Logger => WEBrick::Log.new(IO::NULL),
    :AccessLog => [],
  )
  Thread.new { w.start }
end


#### FIXME UGLY ####

# Serve a directory over HTTP with Ruby
def ruby_web_server(dir, port)
  "ruby -run -e httpd #{dir} -p #{port} 2>/dev/null"
end

DOCKER_IMAGE = "evolvingweb/sitediff"
task :docker_test do |t|
  cmd = [
    ruby_web_server('spec/fixtures/before', 8881),
    ruby_web_server('spec/fixtures/after', 8882),
    'sitediff diff --before-url=http://localhost:8881 --after-url=http://localhost:8882 spec/fixtures/config.yaml',
  ].join(' & ')
  sh 'docker', 'run', '-v', "#{Dir.pwd}:/sitediff", DOCKER_IMAGE,
    'sh', '-c', cmd
end
task :docker_build do |t|
  sh 'docker', 'build', '-t', DOCKER_IMAGE, '.'
end

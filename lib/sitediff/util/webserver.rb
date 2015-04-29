require 'webrick'

class SiteDiff
module Util
class Webserver
# Simple webserver for testing purposes
  DEFAULT_PORT = 13080

  attr_accessor :ports

  # Serve a list of directories
  def initialize(start_port, dirs, params = {})
    start_port ||= DEFAULT_PORT
    @ports = (start_port...(start_port + dirs.size)).to_a

    if params[:announce]
      puts "Serving at #{uris.join(", ")}"
    end

    opts = {}
    if params[:quiet]
      opts[:Logger] = WEBrick::Log.new(IO::NULL)
      opts[:AccessLog] = []
    end

    @threads = []
    dirs.each_with_index do |dir, idx|
      opts[:Port] = @ports[idx]
      opts[:DocumentRoot] = dir
      server = WEBrick::HTTPServer.new(opts)
      @threads << Thread.new { server.start }
    end

    if block_given?
      yield self
      kill
    end
  end

  def kill
    @threads.each { |t| t.kill }
  end

  def wait
    @threads.each { |t| t.join }
  end

  def uris
    ports.map { |p| "http://localhost:#{p}" }
  end


  # Helper to serve one dir
  def self.serve(port, dir, params = {})
    new(port, [dir], params)
  end
end

class FixtureServer < Webserver
  PORT = DEFAULT_PORT + 1
  BASE = 'spec/fixtures/ruby-doc.org'
  NAMES = %w[core-1.9.3 core-2.0]

  def initialize(port = PORT, base = BASE, names = NAMES)
    dirs = names.map { |n| File.join(base, n) }
    super(port, dirs, :quiet => true)
  end

  def before
    uris.first
  end
  def after
    uris.last
  end
end
end
end

# frozen_string_literal: true

require 'webrick'

class SiteDiff
  # SiteDiff Web Server.
  class Webserver
    # Simple web server for testing purposes.
    DEFAULT_PORT = 13_080

    attr_accessor :ports

    # Serve a list of directories
    def initialize(start_port, dirs, opts = {})
      start_port ||= DEFAULT_PORT
      @ports = (start_port...(start_port + dirs.size)).to_a
      @dirs = dirs
      @opts = opts

      setup
      start_servers

      if block_given?
        yield self
        kill
      end
    end

    def kill
      @threads.each(&:kill)
    end

    def wait
      @threads.each(&:join)
    end

    def uris
      ports.map { |p| "http://localhost:#{p}" }
    end

    protected

    def setup
      @server_opts = {}
      if @opts[:quiet]
        @server_opts[:Logger] = WEBrick::Log.new(IO::NULL)
        @server_opts[:AccessLog] = []
      end
    end

    def server(opts)
      WEBrick::HTTPServer.new(opts)
    end

    def start_servers
      @threads = []
      @dirs.each_with_index do |dir, idx|
        @server_opts[:Port] = @ports[idx]
        @server_opts[:DocumentRoot] = dir
        srv = server(@server_opts)
        @threads << Thread.new { srv.start }
      end
    end

    public

    # SiteDiff Fixture Server.
    class FixtureServer < Webserver
      PORT = DEFAULT_PORT + 1
      BASE = 'spec/sites/ruby-doc.org'
      NAMES = %w[core-1.9.3 core-2.0].freeze

      def initialize(port = PORT, base = BASE, names = NAMES)
        dirs = names.map { |n| File.join(base, n) }
        super(port, dirs, quiet: true)
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

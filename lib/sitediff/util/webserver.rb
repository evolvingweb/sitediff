require 'webrick'

class SiteDiff
  module Util
    # Simple webserver for testing purposes
    class Webserver
      attr_accessor :ports

      # Serve a list of directories
      def initialize(start_port, dirs, params = {})
        opts = {}
        if params[:quiet]
          opts[:Logger] = WEBrick::Log.new(IO::NULL)
          opts[:AccessLog] = []
        end

        @ports = []
        @threads = []
        dirs.each_with_index do |dir, idx|
          opts[:Port] = start_port + idx
          @ports << opts[:Port]
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
      PORT = 13081
      BASE = 'spec/fixtures'
      NAMES = %w[before after]

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

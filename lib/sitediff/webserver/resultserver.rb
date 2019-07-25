# frozen_string_literal: true

require 'sitediff'
require 'sitediff/report'
require 'sitediff/webserver'
require 'erb'

class SiteDiff
  class Webserver
    # SiteDiff Result Server.
    class ResultServer < Webserver
      # Display a page from the cache
      class CacheServlet < WEBrick::HTTPServlet::AbstractServlet
        ##
        # Creates a Cache Servlet.
        def initialize(_server, cache)
          @cache = cache
        end

        ##
        # Performs a GET request.
        def do_GET(req, res)
          path = req.path_info
          (md = %r{^/([^/]+)(/.*)$}.match(path)) ||
            raise(WEBrick::HTTPStatus::NotFound)
          tag, path = *md.captures
          (r = @cache.get(tag.to_sym, path)) ||
            raise(WEBrick::HTTPStatus::NotFound)

          raise WEBrick::HTTPStatus[r.error_code] if r.error_code
          raise WEBrick::HTTPStatus::InternalServerError, r.error if r.error

          res['content-type'] = 'text/html'
          res.body = r.content
        end
      end

      ##
      # Display two pages side by side.
      class SideBySideServlet < WEBrick::HTTPServlet::AbstractServlet
        ##
        # Creates a Side By Side Servlet.
        def initialize(_server, cache, settings)
          @cache = cache
          @settings = settings
        end

        ##
        # Generates URLs for a given path.
        def urls(path)
          %w[before after].map do |tag|
            base = @settings[tag]
            base = "/cache/#{tag}" if @settings['cached'].include? tag
            base + path
          end
        end

        ##
        # Performs a GET request.
        def do_GET(req, res)
          path = req.path_info
          before, after = *urls(path)

          res['content-type'] = 'text/html'
          erb = File.join(SiteDiff::FILES_DIR, 'sidebyside.html.erb')
          res.body = ERB.new(File.read(erb)).result(binding)
        end
      end

      ##
      # Run sitediff command from browser. Probably dangerous in general.
      class RunServlet < WEBrick::HTTPServlet::AbstractServlet
        ##
        # Creates a Run Servlet.
        def initialize(_server, dir)
          @dir = dir
        end

        ##
        # Performs a GET request.
        def do_GET(req, res)
          path = req.path_info
          if path != '/diff'
            res['content-type'] = 'text/plain'
            res.body = 'ERROR: Only /run/diff is supported at the moment.'
            return
          end
          # Thor assumes only one command is called and some values like
          # `options` are share across all SiteDiff::Cli instances so
          # we can't just call SiteDiff::Cli.new().diff
          # This is likely to go very wrong depending on how `sitediff serve`
          # was actually called
          cmd = "#{$PROGRAM_NAME} diff -C #{@dir} --cached=all"
          system(cmd)

          # Could also add a message to indicate success/failure
          # But for the moment, all our files are static
          res.set_redirect(WEBrick::HTTPStatus::Found,
                           "/files/#{Report::REPORT_FILE}")
        end
      end

      ##
      # Creates a Result Server.
      def initialize(port, dir, opts = {})
        unless File.exist?(File.join(dir, Report::SETTINGS_FILE))
          raise SiteDiffException,
                "Please run 'sitediff diff' before running 'sitediff serve'"
        end

        @settings = YAML.load_file(File.join(dir, Report::SETTINGS_FILE))
        puts @settings
        @cache = opts[:cache]
        super(port, [dir], opts)
      end

      ##
      # TODO: Document what this method does.
      def server(opts)
        dir = opts.delete(:DocumentRoot)
        srv = super(opts)
        srv.mount_proc('/') do |req, res|
          if req.path == '/'
            res.set_redirect(WEBrick::HTTPStatus::Found,
                             "/files/#{Report::REPORT_FILE}")
          else
            res.set_redirect(WEBrick::HTTPStatus::TemporaryRedirect,
                             "#{@settings['after']}#{req.path}")
          end
        end

        srv.mount('/files', WEBrick::HTTPServlet::FileHandler, dir, true)
        srv.mount('/cache', CacheServlet, @cache)
        srv.mount('/sidebyside', SideBySideServlet, @cache, @settings)
        srv.mount('/run', RunServlet, dir)
        srv
      end

      ##
      # Sets up the server.
      def setup
        super
        root = uris.first
        puts "Serving at #{root}"
        open_in_browser(root) if @opts[:browse]
      end

      ##
      # Opens a URL in a browser.
      def open_in_browser(url)
        commands = %w[xdg-open open]
        cmd = commands.find { |c| which(c) }
        system(cmd, url) if cmd
        cmd
      end

      ##
      # TODO: Document what this method does.
      def which(cmd)
        ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
          file = File.join(path, cmd)
          return file if File.executable?(file)
        end
        nil
      end
    end
  end
end

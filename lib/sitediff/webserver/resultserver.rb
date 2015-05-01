require 'sitediff'
require 'sitediff/webserver'
require 'erb'

class SiteDiff
class Webserver
class ResultServer < Webserver
  # Display a page from the cache
  class CacheServlet < WEBrick::HTTPServlet::AbstractServlet
    def initialize(server, cache)
      @cache = cache
    end

    def do_GET(req, res)
      path = req.path_info
      md = %r[^/([^/]+)(/.*)$].match(path) or
        raise WEBrick::HTTPStatus::NotFound
      tag, path = *md.captures
      r = @cache.get(tag.to_sym, path) or
        raise WEBrick::HTTPStatus::NotFound

      raise WEBrick::HTTPStatus[r.error_code] if r.error_code
      raise WEBrick::HTTPStatus::InternalServerError, r.error if r.error

      res['content-type'] = 'text/html'
      res.body = r.content
    end
  end

  # Display two pages side by side
  class SideBySideServlet < WEBrick::HTTPServlet::AbstractServlet
    def initialize(server, cache, settings)
      @cache = cache
      @settings = settings
    end

    def urls(path)
      %w[before after].map do |tag|
        base = @settings[tag.to_sym] || "/cache/#{tag.to_s}"
        base + path
      end
    end

    def do_GET(req, res)
      path = req.path_info
      before, after = *urls(path)

      res['content-type'] = 'text/html'
      erb = File.join(SiteDiff::FILES_DIR, 'sidebyside.html.erb')
      res.body = ERB.new(File.read(erb)).result(binding)
    end
  end

  def initialize(port, dir, opts = {})
    @settings = YAML.load_file(File.join(dir, SiteDiff::SETTINGS_FILE))
    @cache = opts[:cache]
    super(port, [dir], opts)
  end

  def server(opts)
    dir = opts.delete(:DocumentRoot)
    srv = super(opts)
    srv.mount_proc('/') do |req, res|
      res.set_redirect(WEBrick::HTTPStatus::Found,
        "/files/#{SiteDiff::REPORT_FILE}")
    end

    srv.mount('/files', WEBrick::HTTPServlet::FileHandler, dir, true)
    srv.mount('/cache', CacheServlet, @cache)
    srv.mount('/sidebyside', SideBySideServlet, @cache, @settings)
    return srv
  end

  def setup
    super
    root = uris.first
    puts "Serving at #{root}"
    open_in_browser(root) if @opts[:browse]
  end

  def open_in_browser(url)
    commands = %w[xdg-open open]
    cmd = commands.find { |c| which(c) }
    system(cmd, url) if cmd
    return cmd
  end

  def which(cmd)
    ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
      file = File.join(path, cmd)
      return file if File.executable?(file)
    end
    return nil
  end
end
end
end

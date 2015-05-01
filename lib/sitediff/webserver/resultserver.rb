require 'sitediff/webserver'

class SiteDiff
class Webserver
class ResultServer < Webserver
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

  def initialize(port, dir, opts = {})
    super(port, [dir], opts)
  end

  def server(opts)
    srv = super
    srv.mount('/cache', CacheServlet, @opts[:cache])
    return srv
  end

  def setup
    super
    root = "#{uris.first}/report.html"
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

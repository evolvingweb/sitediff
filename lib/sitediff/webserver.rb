require 'webrick'

class SiteDiff
class Webserver
# Simple webserver for testing purposes
DEFAULT_PORT = 13080

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
  @threads.each { |t| t.kill }
end

def wait
  @threads.each { |t| t.join }
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

class CachingServer < Webserver
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

  def server(opts)
    srv = super
    srv.mount('/cache', CacheServlet, @opts[:cache])
    return srv
  end
end

class ResultServer < CachingServer
  def initialize(port, dir, opts = {})
    super(port, [dir], opts)
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

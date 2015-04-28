require 'sitediff/uriwrapper'
require 'sitediff/crawler'
require 'sitediff/rules'
require 'sitediff/cache'
require 'nokogiri'
require 'yaml'
require 'pathname'

class SiteDiff
class Config
class Creator
  def initialize(*urls)
    @after = urls.pop
    @before = urls.pop # May be nil
  end

  def roots
    @roots = begin
      r = { :after => @after }
      r[:before] = @before if @before
      r
    end
  end

  # Build a config structure, return it
  def create(opts)
    # Handle options
    @dir = Pathname.new(opts[:directory])
    @depth = opts[:depth]

    # Create the dir. Must go before cache initialization!
    @dir.mkpath unless @dir.directory?

    # Setup instance vars
    @paths = Set.new
    @cache = Cache.new(@dir.+(Cache::DEFAULT_FILENAME).to_s)
    @cache.write_tags << roots.keys

    build_config
    write_config
  end

  def build_config
    @config = {}
    %w[before after].each do |tag|
      next unless u = roots[tag.to_sym]
      @config[tag] = {'url' => u}
    end

    crawl(@depth)

    @config['paths'] = @paths.sort
  end

  def crawl(depth = nil)
    hydra = Typhoeus::Hydra.new(max_concurrency: 10)
    roots.each do |tag, u|
      Crawler.new(hydra, u, depth) do |path, html|
        crawled_path(tag, path, html)
      end
    end
    hydra.run
  end

  # Deduplicate paths with slashes at the end
  def is_dup(path)
    return @paths.include?(path) \
      || @paths.include?(path.sub(%r[/$], '')) \
      || @paths.include?(path + '/')
  end

  def crawled_path(tag, path, html)
    return if is_dup(path)

    @paths << path
    @cache.set(tag, path, html)
    # TODO: Do something with rules here
  end

  # Create a gitignore if we seem to be in git
  def make_gitignore(dir)
    # Check if we're in git
    return unless dir.realpath.to_enum(:ascend).any? { |d| d.+('.git').exist? }

    dir.+('.gitignore').open('w') do |f|
      f.puts <<-EOF.gsub(/^\s+/, '')
        output
        cache.db
        cache.db.db
      EOF
    end
  end

  # Turn a config structure into a config file
  def write_config
    make_gitignore(@dir)
    conf = @dir + Config::DEFAULT_FILENAME
    conf.open('w') { |f| f.puts @config.to_yaml }
  end
end
end
end

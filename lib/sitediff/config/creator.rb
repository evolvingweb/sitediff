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
    @cache.write_tags << :before << :after

    build_config
    write_config
  end

  def build_config
    @config = {}
    %w[before after].each do |tag|
      next unless u = roots[tag.to_sym]
      @config[tag] = {'url' => u}
    end

    @rules = Rules.new(@config)
    crawl(@depth)
    @rules.add_config

    @config['paths'] = @paths.sort
  end

  def crawl(depth = nil)
    hydra = Typhoeus::Hydra.new(max_concurrency: 10)
    roots.each do |tag, u|
      Crawler.new(hydra, u, depth) do |path, res, doc|
        crawled_path(tag, path, res, doc)
      end
    end
    hydra.run
  end

  # Deduplicate paths with slashes at the end
  def canonicalize(path)
    p = path + '/'
    return p if @paths.include? p

    p = path.sub(%r[/$], '')
    return p if @paths.include? p

    return '/' if path.empty?
    return path
  end

  def crawled_path(tag, path, res, doc)
    path = canonicalize(path)
    return if @paths.include? path

    @paths << path
    @cache.set(tag, path, res)

    # If single-site, cache after as before!
    @cache.set(:before, path, res) unless roots[:before]

    @rules.handle_page(tag, res.content, doc) unless res.error
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

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
  def initialize(*urls, &block)
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
  def create(opts, &block)
    @config = {}
    @callback = block

    # Handle options
    @dir = Pathname.new(opts[:directory])
    @depth = opts[:depth]
    @rules = Rules.new(@config, opts[:rules_disabled]) if opts[:rules]

    # Create the dir. Must go before cache initialization!
    @dir.mkpath unless @dir.directory?

    # Setup instance vars
    @paths = Hash.new { |h,k| h[k] = Set.new }
    @cache = Cache.new(@dir.+(Cache::DEFAULT_FILENAME).to_s)
    @cache.write_tags << :before << :after

    build_config
    write_config
  end

  def build_config
    %w[before after].each do |tag|
      next unless u = roots[tag.to_sym]
      @config[tag] = {'url' => u}
    end

    crawl(@depth)
    @rules.add_config if @rules

    @config['paths'] = @paths.values.reduce(&:|).to_a.sort
  end

  def crawl(depth = nil)
    hydra = Typhoeus::Hydra.new(max_concurrency: 10)
    roots.each do |tag, u|
      Crawler.new(hydra, u, depth) do |info|
        crawled_path(tag, info)
      end
    end
    hydra.run
  end

  # Deduplicate paths with slashes at the end
  def canonicalize(tag, path)
    def altered_paths(path)
      yield path + '/'
      yield path.sub(%r[/$], '')
    end

    return path.empty? ? '/' : path
  end

  def crawled_path(tag, info)
    path, dup = canonicalize(tag, info.relative)
    return if dup

    res = info.read_result

    @callback[tag, info]
    @paths[tag] << path
    @cache.set(tag, path, res)

    # If single-site, cache after as before!
    @cache.set(:before, path, res) unless roots[:before]

    @rules.handle_page(tag, res.content, info.document) if @rules && !res.error
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

  def config_file
    @dir + Config::DEFAULT_FILENAME
  end

  # Turn a config structure into a config file
  def write_config
    make_gitignore(@dir)
    config_file.open('w') { |f| f.puts @config.to_yaml }
  end
end
end
end

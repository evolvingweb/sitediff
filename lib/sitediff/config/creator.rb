require 'sitediff/uriwrapper'
require 'sitediff/crawler'
require 'sitediff/rules'
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

  # Build a config structure, return it
  def build(opts)
    html_by_uri_by_pos = {}
    depth = opts[:depth]
    html_by_uri_by_pos['after'] = SiteDiff::Crawler.new(@after).crawl(depth)

    @config = {'after' => {'url' => @after }}
    if @before
      @config['before'] = {'url' => @before }
      html_by_uri_by_pos['before'] = SiteDiff::Crawler.new(@before).crawl(depth)
    end

    rules = SiteDiff::Rules.rules_config(html_by_uri_by_pos)
    rules.each do |k, v|
      @config[k] = v
    end

    @config['paths'] = html_by_uri_by_pos.keys.sort

    return @config
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
  def create(config = nil, opts)
    config ||= @config

    dir = Pathname.new(opts[:directory])
    dir.mkpath unless dir.directory?
    make_gitignore(dir)

    conf = dir + Config::DEFAULT_FILENAME
    conf.open('w') { |f| f.puts config.to_yaml }
  end
end
end
end

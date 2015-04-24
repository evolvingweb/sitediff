require 'sitediff/uriwrapper'
require 'sitediff/crawler'
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
    crawler = SiteDiff::Crawler.new(@after)
    found = crawler.crawl(opts[:depth])

    @config = {}
    @config['after_url'] = @after
    @config['before_url'] = @before if @before
    @config['paths'] = found.keys.sort

    return @config
  end

  # Turn a config structure into a config file
  def create(config = nil, opts)
    config ||= @config

    dir = Pathname.new(opts[:directory])
    dir.mkpath unless dir.directory?

    conf = dir + 'config.yaml'
    conf.open('w') { |f| f.puts config.to_yaml }
  end
end
end
end

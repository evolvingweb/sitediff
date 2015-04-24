require 'sitediff/uriwrapper'
require 'sitediff/crawler'
require 'nokogiri'

class SiteDiff
class Config
class Creator
  def initialize(*urls)
    @after = urls.pop
    @before = urls.pop # May be nil
  end

  # Build a config structure, return it
  def build
    crawler = SiteDiff::Crawler.new(@after)
    pages = crawler.crawl
    p pages
    # TODO
  end

  # Turn a config structure into a config file
  def create
    # TODO
  end
end
end
end

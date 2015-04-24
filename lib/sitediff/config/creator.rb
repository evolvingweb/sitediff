require 'sitediff/uriwrapper'
require 'nokogiri'

class SiteDiff
class Config
class Creator
  CRAWL_DEPTH_DEFAULT = 3

  def initialize(*urls)
    @after = urls.pop
    @base = URI(@after)
    @before = urls.pop # May be nil
  end

  # Build a config structure, return it
  def build
    crawl
    # TODO
  end

  # Turn a config structure into a config file
  def create
    # TODO
  end

  # Crawl a site for URLs
  def crawl(depth = CRAWL_DEPTH_DEFAULT)
    hydra = Typhoeus::Hydra.new(max_concurrency: 3)
    pages = []

    wrapper = UriWrapper.new(@base)
    queue = nil
    queue = proc do |relative, depth|
      next if pages.include? relative
      pages << relative
      next unless depth > 0

      wrapper.+(relative).queue(hydra) do |res|
        next unless res.content

        page_uri = URI(@base + relative)
        links = find_links(page_uri, res.content)
        links.each do |l|
          next if pages.include? l
          queue[l, depth - 1]
        end
      end
    end

    queue['/', depth]

    hydra.run

    return @pages
  end

  def find_links(uri, html)
    links = []
    doc = Nokogiri::HTML(html)
    links.concat doc.xpath('//a[@href]').map { |e| e['href'] }

    # Make them absolute
    page = URI(uri.to_s)
    links.map! { |l| page + l }.uniq!

    # Filter out links that point outside our base
    links.keep_if do |l|
      l.host == @base.host && l.path.start_with?(@base.path)
    end

    # Make them relative
    links.map! { |l| l.path.slice(@base.path.length, l.path.length) }

    return links
  end
end
end
end

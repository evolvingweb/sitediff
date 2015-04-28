require 'sitediff/uriwrapper'
require 'typhoeus'
require 'set'
require 'ostruct'

class SiteDiff
class Crawler
  class Info < OpenStruct; end

  DEFAULT_DEPTH = 3

  # Create a crawler with a base URL
  def initialize(hydra, base, depth = DEFAULT_DEPTH, &block)
    @hydra = hydra
    @base_uri = URI(base)
    @base = base
    @found = Set.new
    @callback = block

    add_uri('', depth)
  end

  # Handle a newly found relative URI
  def add_uri(rel, depth)
    return if @found.include? rel
    @found << rel

    wrapper = UriWrapper.new(@base + rel)
    wrapper.queue(@hydra) do |res|
      fetched_uri(rel, depth, res)
    end
  end

  # Handle the fetch of a URI
  def fetched_uri(rel, depth, res)
    return unless res.content # Ignore errors
    return unless depth >= 0

    base = URI(@base + rel)

    # Find links
    doc = Nokogiri::HTML(res.content)
    links = find_links(doc)
    uris = []
    links.each do |l|
      begin
        uris << base + URI.escape(l)
      rescue URI::InvalidURIError
        $stderr.puts "skipped invalid URL: '#{l}'"
      end
    end
    uris = filter_links(uris)

    # Make them relative
    rels = uris.map { |u| u.path.slice(@base_uri.path.length, u.path.length) }

    # Call the callback
    info = Info.new(
      :relative => rel,
      :uri => base,
      :read_result => res,
      :document => doc,
    )
    @callback[info]

    # Queue them in turn
    rels.each do |r|
      next if @found.include? r
      add_uri(r, depth - 1)
    end
  end

  # Return a list of string links found on a page.
  def find_links(doc)
    return doc.xpath('//a[@href]').map { |e| e['href'] }
  end

  # Filter out links we don't want. Links passed in are absolute URIs.
  def filter_links(uris)
    uris.find_all do |u|
      u.host == @base_uri.host && u.path.start_with?(@base_uri.path)
    end
  end
end
end

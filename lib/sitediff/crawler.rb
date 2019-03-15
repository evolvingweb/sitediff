# frozen_string_literal: true

require 'sitediff'
require 'sitediff/uriwrapper'
require 'addressable/uri'
require 'nokogiri'
require 'ostruct'
require 'set'

class SiteDiff
  class Crawler
    class Info < OpenStruct; end

    DEFAULT_DEPTH = 3

    # Create a crawler with a base URL
    def initialize(hydra, base,
                   interval,
                   depth = DEFAULT_DEPTH,
                   curl_opts = UriWrapper::DEFAULT_CURL_OPTS,
                   debug = true,
                   &block)
      @hydra = hydra
      @base_uri = Addressable::URI.parse(base)
      @base = base
      @interval = interval
      @found = Set.new
      @callback = block
      @curl_opts = curl_opts
      @debug = debug

      add_uri('', depth)
    end

    # Handle a newly found relative URI
    def add_uri(rel, depth)
      return if @found.include? rel

      @found << rel

      # Insert delay to limit fetching rate
      if @interval != 0
        SiteDiff.log("Waiting #{@interval} milliseconds.", :info)
        sleep(@interval / 1000.0)
      end

      wrapper = UriWrapper.new(@base + rel, @curl_opts, @debug)
      wrapper.queue(@hydra) do |res|
        fetched_uri(rel, depth, res)
      end
    end

    # Handle the fetch of a URI
    def fetched_uri(rel, depth, res)
      if res.error
        SiteDiff.log(res.error, :error)
        return
      elsif !res.content
        SiteDiff.log('Response is missing content. Treating as an error.', :error)
        return
      end

      base = Addressable::URI.parse(@base + rel)
      doc = Nokogiri::HTML(res.content)

      # Call the callback
      info = Info.new(
        relative: rel,
        uri: base,
        read_result: res,
        document: doc
      )
      @callback[info]

      return unless depth >= 1

      # Find links
      links = find_links(doc)
      uris = links.map { |l| resolve_link(base, l) }.compact
      uris = filter_links(uris)

      # Make them relative
      rels = uris.map { |u| relativize_link(u) }

      # Queue them in turn
      rels.each do |r|
        next if @found.include? r

        add_uri(r, depth - 1)
      end
    end

    # Resolve a potentially-relative link. Return nil on error.
    def resolve_link(base, rel)
      base + rel
    rescue Addressable::URI::InvalidURIError
      SiteDiff.log "skipped invalid URL: '#{rel}' (at #{base})", :warn
      nil
    end

    # Make a link relative to @base_uri
    def relativize_link(uri)
      uri.path.slice(@base_uri.path.length, uri.path.length)
    end

    # Return a list of string links found on a page.
    def find_links(doc)
      doc.xpath('//a[@href]').map { |e| e['href'] }
    end

    # Filter out links we don't want. Links passed in are absolute URIs.
    def filter_links(uris)
      uris.find_all do |u|
        u.host == @base_uri.host && u.path.start_with?(@base_uri.path)
      end
    end
  end
end

# frozen_string_literal: true

require 'sitediff'
require 'sitediff/uriwrapper'
require 'addressable/uri'
require 'nokogiri'
require 'ostruct'
require 'set'

class SiteDiff
  # SiteDiff Crawler.
  class Crawler
    class Info < OpenStruct; end

    DEFAULT_DEPTH = 3

    # Create a crawler with a base URL
    def initialize(hydra, base,
                   interval,
                   include_regex,
                   exclude_regex,
                   depth = DEFAULT_DEPTH,
                   curl_opts = UriWrapper::DEFAULT_CURL_OPTS,
                   debug: true,
                   &block)
      @hydra = hydra
      @base_uri = Addressable::URI.parse(base)
      @base = base
      @interval = interval
      @include_regex = include_regex
      @exclude_regex = exclude_regex
      @found = Set.new
      @callback = block
      @curl_opts = curl_opts
      @debug = debug

      add_uri('', depth, referrer: '/')
    end

    # Handle a newly found relative URI
    def add_uri(rel, depth, referrer = '')
      return if @found.include? rel

      @found << rel

      wrapper = UriWrapper.new(@base + rel, @curl_opts, debug: @debug, referrer:)
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
      # Insert delay to limit fetching rate
      if @interval != 0
        SiteDiff.log("Waiting #{@interval} milliseconds.", :info)
        sleep(@interval / 1000.0)
      end
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

        add_uri(r, depth - 1, rel)
      end
    end

    # Resolve a potentially-relative link. Return nil on error.
    def resolve_link(base, rel)
      rel = rel.strip
      base + rel
    rescue Addressable::URI::InvalidURIError
      SiteDiff.log "skipped invalid URL: '#{rel}' (at #{base})", :warning
      nil
    end

    # Make a link relative to @base_uri
    def relativize_link(uri)
      # fullPath = uri.path
      # if uri.query
      #   fullPath += "?" + uri.query
      # end
      #
      # if uri.fragment
      #   fullPath += "#" + uri.fragment
      # end
      # fullPath.gsub(@base_uri.path, "")
      #
      uri.path.slice(@base_uri.path.length, uri.path.length)
    end

    # Return a list of string links found on a page.
    def find_links(doc)
      doc.xpath('//a[@href]').map { |e| e['href'] }
    end

    # Filter out links we don't want. Links passed in are absolute URIs.
    def filter_links(uris)
      uris.find_all do |u|
        is_sub_uri = (u.host == @base_uri.host) &&
                     u.path.start_with?(@base_uri.path)
        next unless is_sub_uri

        # puts "Trying regex #{u.path}"
        is_included = @include_regex.nil? ? false : @include_regex.match(u.path)
        is_excluded = @exclude_regex.nil? ? false : @exclude_regex.match(u.path)
        if is_excluded && !is_included
          SiteDiff.log "Ignoring excluded URL #{u.path}", :debug
        end
        is_included || !is_excluded
      end
    end
  end
end

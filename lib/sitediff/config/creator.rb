# frozen_string_literal: true

require 'sitediff/cache'
require 'sitediff/config'
require 'sitediff/crawler'
require 'sitediff/rules'
require 'pathname'
require 'typhoeus'
require 'yaml'

class SiteDiff
  class Config
    ##
    # SiteDiff Config Creator Object.
    class Creator

      ##
      # The config which is currently being built.
      @config

      ##
      # Creates a Creator object.
      # TODO: Use named arguments or a hash instead.
      def initialize(concurrency,
                     interval,
                     whitelist,
                     blacklist,
                     curl_opts,
                     debug,
                     *urls)
        @concurrency = concurrency
        @interval = interval
        @whitelist = whitelist
        @blacklist = blacklist
        @after = urls.pop
        @before = urls.pop # May be nil
        @curl_opts = curl_opts
        @debug = debug
      end

      ##
      # Determine if we're dealing with one or two URLs.
      def roots
        @roots = { after: @after }
        @roots[:before] = @before if @before
        @roots
      end

      ##
      # Build a config structure, return it.
      def create(options, &block)
        @config = {}
        @callback = block
        @dir = Pathname.new(options[:directory])

        # Handle other options
        @depth = options[:depth]
        @rules = Rules.new(@config, options[:rules_disabled]) if options[:rules]

        # Setup instance vars
        @paths = Hash.new { |h, k| h[k] = Set.new }
        @cache = Cache.new(directory: @dir.to_s, create: true)
        @cache.write_tags << :before << :after

        build_config
        write_config
      end

      ##
      # Build and populate the config object which is being created.
      def build_config
        %w[before after].each do |tag|
          next unless (url = roots[tag.to_sym])

          @config[tag] = { 'url' => url }
        end

        crawl(@depth)
        @rules&.add_config

        @config['paths'] = @paths.values.reduce(&:|).to_a.sort
      end

      ##
      # Crawls the "before" site to determine "paths".
      def crawl(depth = nil)
        hydra = Typhoeus::Hydra.new(max_concurrency: @concurrency)
        roots.each do |tag, url|
          Crawler.new(hydra,
                      url,
                      @interval,
                      @whitelist,
                      @blacklist,
                      depth,
                      @curl_opts,
                      @debug) do |info|
            crawled_path(tag, info)
          end
        end
        hydra.run
      end

      ##
      # Canonicalize a path.
      # TODO: Remove "_tag" if it is not required.
      def canonicalize(_tag, path)
        # Ignore trailing slashes.
        path = path.chomp('/')
        # If the path is empty after removing the trailing slash, it implies
        # that we're on the front page, so we restore the "/".
        path.empty? ? '/' : path
      end

      ##
      # Process info about a crawled path.
      def crawled_path(tag, info)
        path, dup = canonicalize(tag, info.relative)
        return if dup

        res = info.read_result

        @callback[tag, info]
        @paths[tag] << path
        @cache.set(tag, path, res)

        # If single-site, cache after as before!
        @cache.set(:before, path, res) unless roots[:before]

        # This is used to populate the list of rules we guess are
        # applicable to the current site.
        @rules.handle_page(tag, res.content, info.document) if @rules && !res.error
      end

      ##
      # Create a gitignore if we seem to be in git.
      def make_gitignore(dir)
        # Check if we're in git
        return unless dir.realpath.to_enum(:ascend).any? { |d| d.+('.git').exist? }

        dir.+('.gitignore').open('w') do |f|
          f.puts <<-GITIGNORE.gsub(/^\s+/, '')
            snapshot
            settings.yaml
          GITIGNORE
        end
      end

      ##
      # Returns the name of the config directory.
      def directory
        @dir
      end

      ##
      # Returns the name of the config file.
      def config_file
        @dir + Config::DEFAULT_FILENAME
      end

      ##
      # Writes the built config into the config file.
      def write_config
        make_gitignore(@dir)
        config_file.open('w') { |f| f.puts @config.to_yaml }
      end
    end
  end
end

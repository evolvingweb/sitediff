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
    # SiteDiff Config Creator Object.
    class Creator
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

      def roots
        @roots = begin
          r = { after: @after }
          r[:before] = @before if @before
          r
        end
      end

      # Build a config structure, return it
      def create(opts, &block)
        @config = {}
        @callback = block
        @dir = Pathname.new(opts[:directory])

        # Handle other options
        @depth = opts[:depth]
        @rules = Rules.new(@config, opts[:rules_disabled]) if opts[:rules]

        # Setup instance vars
        @paths = Hash.new { |h, k| h[k] = Set.new }
        @cache = Cache.new(directory: @dir.to_s, create: true)
        @cache.write_tags << :before << :after

        build_config
        write_config
      end

      def build_config
        %w[before after].each do |tag|
          next unless (u = roots[tag.to_sym])

          @config[tag] = { 'url' => u }
        end

        crawl(@depth)
        @rules&.add_config

        @config['paths'] = @paths.values.reduce(&:|).to_a.sort
      end

      def crawl(depth = nil)
        hydra = Typhoeus::Hydra.new(max_concurrency: @concurrency)
        roots.each do |tag, u|
          Crawler.new(hydra,
                      u,
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

      # Canonicalize a path.
      # TODO: Remove "_tag" if it is not required.
      def canonicalize(_tag, path)
        # Ignore trailing slashes.
        path = path.chomp('/')
        # If the path is empty after removing the trailing slash, it implies
        # that we're on the front page, so we restore the "/".
        path.empty? ? '/' : path
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

        # This is used to populate the list of rules we guess are
        # applicable to the current site.
        @rules.handle_page(tag, res.content, info.document) if @rules && !res.error
      end

      # Create a gitignore if we seem to be in git
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

      def directory
        @dir
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

# frozen_string_literal: true

require 'sitediff/cache'
require 'sitediff/config'
require 'sitediff/crawler'
require 'pathname'
require 'typhoeus'
require 'yaml'

class SiteDiff
  class Config
    ##
    # SiteDiff Config Creator Object.
    class Creator
      ##
      # Creates a Creator object.
      def initialize(debug, before, after)
        @config = nil
        @before = before
        @after = after
        @debug = debug
      end

      ##
      # Determine if we're dealing with one or two URLs.
      def roots
        @roots = { 'after' => @after }
        @roots['before'] = @before || @after
        @roots
      end

      ##
      # Build a config structure, return it.

      # def create(options, &block)

      def create(options)
        @config = {}

        # @callback = block

        @dir = Pathname.new(options[:directory])

        # Setup instance vars
        @paths = Hash.new { |h, k| h[k] = Set.new }
        @cache = Cache.new(directory: @dir.to_s, create: true)
        @cache.write_tags << :before << :after

        build_config options
        write_config
      end

      ##
      # Build and populate the config object which is being created.
      #
      # @param [String] options
      #   One or more options.
      def build_config(options)
        options = Config.stringify_keys options

        # Build config for "before" and "after".
        %w[before after].each do |tag|
          next unless (url = roots[tag])

          @config[tag] = { 'url' => url }
        end

        # Build other settings.
        @config['settings'] = {}
        Config::ALLOWED_SETTINGS_KEYS.each do |key|
          @config['settings'][key] = options[key]
        end
      end

      ##
      # Create a gitignore if we seem to be in git.
      def make_gitignore(dir)
        # Check if we're in git
        unless dir.realpath.to_enum(:ascend).any? { |d| d.+('.git').exist? }
          return
        end

        dir.+('.gitignore').open('w') do |f|
          f.puts <<-GITIGNORE.gsub(/^\s+/, '')
            # Directories.
            diffs
            snapshot

            # Files.
            settings.yaml
            paths.txt
            failures.txt
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
      # TODO: Exclude default params before writing.
      def write_config
        make_gitignore(@dir)
        data = Config.remove_defaults(@config)
        config_file.open('w') { |f| f.puts data.to_yaml }
      end
    end
  end
end

# frozen_string_literal: true

require 'sitediff/config/preset'
require 'sitediff/exception'
require 'sitediff/sanitize'
require 'pathname'
require 'yaml'

class SiteDiff
  # SiteDiff Configuration.
  class Config
    # Default config file.
    DEFAULT_FILENAME = 'sitediff.yaml'

    # Default paths file.
    DEFAULT_PATHS_FILENAME = 'paths.txt'

    # Default SiteDiff config.
    DEFAULT_CONFIG = {
      'settings' => {
        'depth' => 3,
        'interval' => 0,
        'whitelist' => '',
        'blacklist' => '',
        'concurrency' => 3,
        'preset' => nil
      },
      'before' => {},
      'after' => {},
      'paths' => []
    }.freeze

    # Keys allowed in config files.
    # TODO: Deprecate repeated params before_url and after_url.
    # TODO: Create a method self.supports
    # TODO: Deprecate in favor of self.supports key, subkey, subkey...
    ALLOWED_CONFIG_KEYS = Sanitizer::TOOLS.values.flatten(1) + %w[
      includes
      settings
      before
      after
      before_url
      after_url
    ]

    ##
    # Keys allowed in the "settings" key.
    # TODO: Create a method self.supports
    # TODO: Deprecate in favor of self.supports key, subkey, subkey...
    ALLOWED_SETTINGS_KEYS = %w[
      preset
      depth
      whitelist
      blacklist
      concurrency
      interval
      curl_opts
    ].freeze

    class InvalidConfig < SiteDiffException; end
    class ConfigNotFound < SiteDiffException; end

    # Takes a Hash and normalizes it to the following form by merging globals
    # into before and after. A normalized config Hash looks like this:
    #
    #     paths:
    #     - /about
    #
    #     before:
    #       url: http://before
    #       selector: body
    #       dom_transform:
    #       - type: remove
    #         selector: script
    #
    #     after:
    #       url: http://after
    #       selector: body
    #
    def self.normalize(conf)
      tools = Sanitizer::TOOLS

      # Merge globals
      %w[before after].each do |pos|
        conf[pos] ||= {}
        tools[:array].each do |key|
          conf[pos][key] ||= []
          conf[pos][key] += conf[key] if conf[key]
        end
        tools[:scalar].each { |key| conf[pos][key] ||= conf[key] }
        conf[pos]['url'] ||= conf[pos + '_url']
        conf[pos]['curl_opts'] = conf['curl_opts']
      end

      # Normalize paths.
      conf['paths'] = Config.normalize_paths(conf['paths'])

      conf.select { |k, _v| ALLOWED_CONFIG_KEYS.include? k }
    end

    # Merges two normalized Hashes according to the following rules:
    # 1 paths are merged as arrays.
    # 2 before and after: for each subhash H (e.g. ['before']['dom_transform']):
    #   a)  if first[H] and second[H] are expected to be arrays, their values
    #       are merged as such,
    #   b)  if first[H] and second[H] are expected to be scalars, the value for
    #       second[H] is kept if and only if first[H] is nil.
    #
    # For example, merge(h1, h2) results in h3:
    #
    # (h1) before: {selector: foo, sanitization: [pattern: foo]}
    # (h2) before: {selector: bar, sanitization: [pattern: bar]}
    # (h3) before: {selector: foo, sanitization: [pattern: foo, pattern: bar]}
    def self.merge(first, second)
      result = {
        'paths' => [],
        'before' => {},
        'after' => {},
        'settings' => {}
      }

      # Merge sanitization rules.
      Sanitizer::TOOLS.values.flatten(1).each do |key|
        result[key] = second[key] || first[key]
        result.delete(key) unless result[key]
      end

      # Always merge paths as an array.
      result['paths'] = (first['paths'] || []) + (second['paths'] || [])

      # Rule 1.
      %w[before after].each do |pos|
        first[pos] ||= {}
        second[pos] ||= {}

        # If only the second hash has the value.
        unless first[pos]
          result[pos] = second[pos] || {}
          next
        end

        result[pos] = first[pos].merge!(second[pos]) do |key, a, b|
          # Rule 2a.
          result[pos][key] = if Sanitizer::TOOLS[:array].include? key
                               (a || []) + (b || [])
                             elsif key == 'settings'
                               b
                             else
                               a || b # Rule 2b.
                             end
        end
      end

      # Merge settings.
      result['settings'] = merge_deep(
        first['settings'] || {},
        second['settings'] || {}
      )

      result
    end

    ##
    # Merges 2 iterable objects deeply.
    def self.merge_deep(first, second)
      first.merge(second) do |_key, val1, val2|
        if val1.is_a? Hash
          self.class.merge_deep(val1, val2 || {})
        elsif val1.is_a? Array
          val1 + (val2 || [])
        else
          val2
        end
      end
    end

    ##
    # Gets all loaded configuration except defaults.
    #
    # @return [Hash]
    #   Config data.
    def all
      result = Marshal.load(Marshal.dump(@config))
      self.class.remove_defaults(result)
    end

    ##
    # Removes default parameters from a config hash.
    #
    # I know this is weird, but it'll be fixed. The config management needs to
    # be streamlined further.
    def self.remove_defaults(data)
      # Create a deep copy of the config data.
      result = data

      # Exclude default settings.
      result['settings'].delete_if do |key, value|
        value == DEFAULT_CONFIG['settings'][key] || !value
      end

      # Exclude default curl opts.
      result['settings']['curl_opts'] ||= {}
      result['settings']['curl_opts'].delete_if do |key, value|
        value == UriWrapper::DEFAULT_CURL_OPTS[key.to_sym]
      end

      # Delete curl opts if empty.
      unless result['settings']['curl_opts'].length.positive?
        result['settings'].delete('curl_opts')
      end

      result
    end

    # Creates a SiteDiff Config object.
    def initialize(file, directory)
      # Fallback to default config filename, if none is specified.
      file = File.join(directory, DEFAULT_FILENAME) if file.nil?
      unless File.exist?(file)
        path = File.expand_path(file)
        raise InvalidConfig, "Missing config file #{path}."
      end
      @config = Config.merge(DEFAULT_CONFIG, Config.load_conf(file))
      @file = file
      @directory = directory

      # Validate configurations.
      validate
    end

    # Get "before" site configuration.
    def before(apply_preset = false)
      section :before, apply_preset
    end

    # Get "before" site URL.
    def before_url
      result = before
      result['url'] if result
    end

    # Get "after" site configuration.
    def after(apply_preset = false)
      section :after, apply_preset
    end

    # Get "after" site URL.
    def after_url
      result = after
      result['url'] if result
    end

    # Get paths.
    def paths
      @config['paths']
    end

    # Set paths.
    def paths=(paths)
      raise 'Paths must be an Array' unless paths.is_a? Array

      @config['paths'] = Config.normalize_paths(paths)
    end

    ##
    # Writes an array of paths to a file.
    #
    # @param [Array] paths
    #   An array of paths.
    # @param [String] file
    #   Optional path to a file.
    def paths_file_write(paths, file = nil)
      unless paths.is_a?(Array) && paths.length.positive?
        raise SiteDiffException, 'Write failed. Invalid paths.'
      end

      file ||= File.join(@directory, DEFAULT_PATHS_FILENAME)
      File.open(file, 'w+') { |f| f.puts(paths) }
    end

    ##
    # Reads a collection of paths from a file.
    #
    # @param [String] file
    #   A file containing one path per line.
    #
    # @return [Integer]
    #   Number of paths read.
    def paths_file_read(file = nil)
      file ||= File.join(@directory, DEFAULT_PATHS_FILENAME)

      raise Config::InvalidConfig, "File not found: #{file}" unless File.exist? file

      self.paths = File.readlines(file)

      # Return the number of paths.
      paths.length
    end

    ##
    # Get roots.
    #
    # Example: If the config has a "before" and "after" sections, then roots
    # will be ["before", "after"].
    def roots
      @roots = { 'after' => after_url }
      @roots['before'] = before_url if before
      @roots
    end

    ##
    # Gets a setting.
    #
    # @param [String] key
    #   A key.
    #
    # @return [*]
    #   A value, if exists.
    def setting(key)
      key = key.to_s if key.is_a?(Symbol)
      return @config['settings'][key] if @config['settings'].key?(key)
    end

    ##
    # Gets all settings.
    #
    # TODO: Make sure the settings are not writable.
    #
    # @return [Hash]
    #   All settings.
    def settings
      @config['settings']
    end

    # Checks if the configuration is usable for diff-ing.
    # TODO: Do we actually need the opts argument?
    def validate(opts = {})
      opts = { need_before: true }.merge(opts)

      if opts[:need_before] && !before['url']
        raise InvalidConfig, "Undefined 'before' base URL."
      end

      raise InvalidConfig, "Undefined 'after' base URL." unless after['url']

      # Validate interval and concurrency.
      interval = setting(:interval)
      concurrency = setting(:concurrency)
      if interval.to_i != 0 && concurrency != 1
        raise InvalidConfig, 'Concurrency must be 1 when an interval is set.'
      end

      # Validate preset.
      Preset.exist? setting(:preset), true if setting(:preset)
    end

    ##
    # Returns object clone with stringified keys.
    # TODO: Make this method available globally, if required.
    def self.stringify_keys(object)
      # Do nothing if it is not an object.
      return object unless object.respond_to?('each_key')

      # Convert symbol indices to strings.
      output = {}
      object.each_key do |old_k|
        new_k = old_k.is_a?(Symbol) ? old_k.to_s : old_k
        output[new_k] = stringify_keys object[old_k]
      end

      # Return the new hash with string indices.
      output
    end

    ##
    # Creates a RegExp from a string.
    def self.create_regexp(string_param)
      begin
        @return_value = string_param == '' ? nil : Regexp.new(string_param)
      rescue SiteDiffException => e
        @return_value = nil
        SiteDiff.log 'Invalid RegExp: ' + string_param, :error
        SiteDiff.log e.message, :error
        # TODO: Use SiteDiff.log type :debug
        # SiteDiff.log e.backtrace, :error if options[:verbose]
      end
      @return_value
    end

    private

    ##
    # Returns one of the "before" or "after" sections.
    #
    # @param [String|Symbol]
    #   Section name. Example: before, after.
    # @param [Boolean] with_preset
    #   Whether to merge with preset config (if any).
    #
    # @return [Hash|Nil]
    #   Section data or Nil.
    def section(name, with_preset = false)
      name = name.to_s if name.is_a? Symbol

      # Validate section.
      unless %w[before after].include? name
        raise SiteDiffException, '"name" must be one of "before" or "after".'
      end

      # Return nil if section is not defined.
      nil unless @config[name]
      result = @config[name]

      # Merge preset rules, if required.
      preset = setting(:preset)
      if with_preset && !preset.nil?
        preset_config = Preset.read preset
        result = Config.merge preset_config, result
      end

      result
    end

    def self.normalize_paths(paths)
      paths ||= []
      paths.map { |p| (p[0] == '/' ? p : "/#{p}").chomp }
    end

    # reads a YAML file and raises an InvalidConfig if the file is not valid.
    def self.load_raw_yaml(file)
      SiteDiff.log "Reading config file: #{Pathname.new(file).expand_path}"
      conf = YAML.load_file(file) || {}

      unless conf.is_a? Hash
        raise InvalidConfig, "Invalid configuration file: '#{file}'"
      end

      conf.each_key do |k, _v|
        unless ALLOWED_CONFIG_KEYS.include? k
          raise InvalidConfig, "Unknown configuration key (#{file}): '#{k}'"
        end
      end

      conf
    end

    # loads a single YAML configuration file, merges all its 'included' files
    # and returns a normalized Hash.
    def self.load_conf(file, visited = [])
      # don't get fooled by a/../a/ or symlinks
      file = File.realpath(file)
      if visited.include? file
        raise InvalidConfig, "Circular dependency: #{file}"
      end

      conf = load_raw_yaml(file) # not normalized yet
      visited << file

      # normalize and merge includes
      includes = conf['includes'] || []
      conf = Config.normalize(conf)
      includes.each do |dep|
        # include paths are relative to the including file.
        dep = File.join(File.dirname(file), dep)
        conf = Config.merge(conf, load_conf(dep, visited))
      end
      conf
    end
  end
end

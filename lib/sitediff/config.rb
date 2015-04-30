require 'sitediff/exception'
require 'yaml'
require 'pathname'

class SiteDiff
  class Config
    DEFAULT_FILENAME = 'sitediff.yaml'

    # keys allowed in configuration files
    CONF_KEYS = Sanitizer::TOOLS.values.flatten(1) +
                %w[paths before after before_url after_url includes]

    class InvalidConfig < SiteDiffException; end

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

      # merge globals
      %w[before after].each do |pos|
        conf[pos] ||= {}
        tools[:array].each do |key|
          conf[pos][key] ||= []
          conf[pos][key] += conf[key] if conf[key]
        end
        tools[:scalar].each {|key| conf[pos][key] ||= conf[key]}
        conf[pos]['url'] ||= conf[pos + '_url']
      end
      # normalize paths
      conf['paths'] = Config::normalize_paths(conf['paths'])

      conf.select {|k,v| %w[before after paths].include? k}
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
      result = { 'paths' => {}, 'before' => {}, 'after' => {} }
      result['paths'] = (first['paths'] || []) + (second['paths'] || []) # rule 1
      %w[before after].each do |pos|
        unless first[pos]
          result[pos] = second[pos] || {}
          next
        end
        result[pos] = first[pos].merge!(second[pos]) do |key, a, b|
          if Sanitizer::TOOLS[:array].include? key # rule 2a
            result[pos][key] = (a || []) + (b|| [])
          else
            result[pos][key] = a || b # rule 2b
          end
        end
      end
      result
    end

    # Search for a config file. If found, change to the containing directory,
    # and return an array of config files found.
    def self.search
      subdirs = %w[. sitediff]
      root_indicators = %w[.git .svn]

      Pathname.pwd.ascend do |dir|
        subdirs.each do |subdir|
          d = dir + subdir + DEFAULT_FILENAME
          if d.exist?
            Dir.chdir(dir.+(subdir).to_s)
            return [DEFAULT_FILENAME]
          end
        end

        root_indicators.each { |r| return [] if dir.+(r).exist? }
      end

      return []
    end

    def initialize(files, opts = {})
      @config = {'paths' => [], 'before' => {}, 'after' => {} }

      files = Config.search if files.empty? && opts[:search]
      files = [DEFAULT_FILENAME] if files.empty? &&
        File.exists?(DEFAULT_FILENAME)
      raise InvalidConfig, "No configuration file found." if files.empty?

      files.each do |file|
        raise InvalidConfig, "Missing config file %s." % file \
          unless File.exist?(file)
        @config = Config::merge(@config, Config::load_conf(file))
      end
    end

    def before
      @config['before']
    end
    def after
      @config['after']
    end

    def paths
      @config['paths']
    end
    def paths=(paths)
      @config['paths'] = Config::normalize_paths(paths)
    end

    # Checks if the configuration is usable for diff-ing.
    def validate(opts = {})
      opts = { :need_before => true }.merge(opts)

      raise InvalidConfig, "Undefined 'before' base URL." if \
        opts[:need_before] && !before['url']
      raise InvalidConfig, "Undefined 'after' base URL." unless after['url']
      raise InvalidConfig, "Undefined 'paths'." unless (paths and !paths.empty?)
    end

    private

    def self.normalize_paths(paths)
      paths ||= []
      return paths.map { |p| (p[0] == '/' ? p : "/#{p}").chomp }
    end

    # reads a YAML file and raises an InvalidConfig if the file is not valid.
    def self.load_raw_yaml(file)
      SiteDiff::log "Reading config file: #{file}"
      conf = YAML.load_file(file) || {}
      unless conf.is_a? Hash
        raise InvalidConfig, "Invalid configuration file: '#{file}'"
      end
      conf.each do |k,v|
        unless CONF_KEYS.include? k
          raise InvalidConfig, "Unknown configuration key (#{file}): '#{k}'"
        end
      end
      conf
    end

    # loads a single YAML configuration file, merges all its 'included' files
    # and returns a normalized Hash.
    def self.load_conf(file, visited=[])
      # don't get fooled by a/../a/ or symlinks
      file = File.realpath(file)
      if visited.include? file
        raise InvalidConfig, "Circular dependency: #{file}"
      end

      conf = load_raw_yaml(file) # not normalized yet
      visited << file

      # normalize and merge includes
      includes = conf['includes'] || []
      conf = Config::normalize(conf)
      includes.each do |dep|
        # include paths are relative to the including file.
        dep = File.join(File.dirname(file), dep)
        conf = Config::merge(conf, load_conf(dep, visited))
      end
      conf
    end
  end
end

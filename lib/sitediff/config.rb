require 'yaml'

class SiteDiff
  class Config

    # keys allowed in configuration files
    CONF_KEYS = Sanitize::TOOLS.values.flatten(1) +
                %w[paths before after before_url after_url includes]

    class InvalidConfig < Exception; end

    # Takes a Hash and normalizes it to the following form by merging globals
    # into before and after:
    #   { 'before' => {...}, 'after' =>  {...}, 'paths' => [...] }
    def self.normalize(conf)
      tools = Sanitize::TOOLS
      %w[before after].each do |pos|
        conf[pos] ||= {}
        tools[:array].each  {|key| conf[pos][key] ||= []}
        tools[:array].each  {|key| conf[pos][key] += conf[key] || []}
        tools[:scalar].each {|key| conf[pos][key] ||= conf[key]}
        conf[pos]['url'] ||= conf[pos + '_url']
      end

      conf.select {|k,v| %w[before after paths].include? k}
    end

    # Merges two normalized Hashes with no conflict resolution.
    def self.merge(first, second)
      result = {
        'paths' => (first['paths'] || []) + (second['paths'] || []),
        'before' => {},
        'after' => {}
      }
      %w[before after].each do |pos|
        unless first[pos]
          result[pos] = second[pos] || {}
          next
        end
        result[pos] = first[pos].merge!(second[pos]) do |key, a, b|
          if Sanitize::TOOLS[:array].include? key
            result[pos][key] = a + b
          elsif !(a and b) # at least one is nil: clean merge
            result[pos][key] = a || b
          else
            raise InvalidConfig,
              "Merge conflict (#{context}['#{pos}']): '#{key}' cannot be cleanly merged."
          end
        end
      end
      result
    end

    attr_reader :paths

    def initialize(files)
      @config = {'paths' => [], 'before' => {}, 'after' => {} }
      files.each {|f| @config = Config::merge(@config, load_conf(f))}
      self.paths = @config['paths']
    end

    def before
      @config['before']
    end
    def after
      @config['after']
    end

    # Sets the array of paths for comparison.
    #
    # Defaults to single path '/' if none specified and ensures all paths start
    # with '/'.
    def paths=(paths)
      paths = ['/'] unless paths and !paths.empty?
      @paths = paths.map do |p|
        p = p.chomp
        p[0] == '/' ? p : p.prepend('/')
      end
    end
    def paths
      @paths
    end

    def validate
      raise InvalidConfig, "Undefined 'before' base URL." unless before['url']
      raise InvalidConfig, "Undefined 'after' base URL." unless after['url']
      raise InvalidConfig, "Undefined 'paths'." unless (paths and !paths.empty?)
    end

    private

    # loads a single YAML configuration file, merges all its 'included' files
    # and returns a normalized Hash. Catches circular dependencies via
    # @loaded_files.
    def load_conf(file)
      @visited_files ||= []
      if @visited_files.include? file
        raise InvalidConfig, "Circular dependency: #{file}"
      end
      SiteDiff::log "Reading config file: #{file}"
      conf = YAML.load_file(file)
      conf.each do |k,v|
        unless CONF_KEYS.include? k
          raise InvalidConfig, "Unknown configuration key (#{file}): '#{k}'"
        end
      end
      @visited_files << file
      includes = conf['includes'] || []
      conf = Config::normalize(conf)
      includes.each do |dep|
        dep_file = File.join(File.dirname(file), dep)
        dep_conf = Config::normalize(load_conf(dep_file))
        conf = Config::merge(conf, dep_conf)
        @visited_files << dep_file
      end
      conf
    end

  end
end

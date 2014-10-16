require 'yaml'

class SiteDiff
  class Config
    class InvalidConfig < Exception; end
    # Contains all configuration for any of before or after: url,
    # and all the transformation rules defined in Sanitize.
    class Site < Struct.new(:url)
      attr_reader :spec
      def initialize(url, spec)
        super(url)
        @spec = {}
        tools = Sanitize::TOOLS
        tools[:array].each do |key|
          @spec[key] = spec[key.to_s] || []
        end
        tools[:scalar].each do |key|
          @spec[key] = spec[key.to_s]
        end
      end

    end

    # Reads and merges provided configuration files and fetches dependencies
    # defined via 'includes'.
    attr_reader :before, :after, :paths
    def initialize(files)
      conf = load_conf(files)
      @before = Site.new(conf['before_url'], conf['before'])
      @after = Site.new(conf['after_url'],  conf['after'])
      self.paths = conf['paths']
    end

    def validate
      raise InvalidConfig.new("Undefined 'before' base URL.") unless before.url
      raise InvalidConfig.new("Undefined 'after' base URL.") unless after.url
    end

    # Returns a configuration hash from an array of YAML configuration files.
    #
    # 1. Included files are merged into the final hash,
    # 2. Global configuration is merged into 'before' and 'after' subhashes with
    #    appropriate overriding rules
    def load_conf(files)
      conf = {}
      files.each do |file|
        SiteDiff::log "Reading config file: #{file}"
        conf_item = YAML.load_file(file)

        # support 1 level of recursion via "includes:" key
        if deps = conf_item.delete("includes")
          deps.each do |dep|
            dep_file = File.join(File.dirname(file), dep)
            SiteDiff::log "Reading dependent config file: #{dep_file}"
            dep_conf = YAML.load_file(dep_file)
            config_merge(conf, dep_conf)
          end
        end
        config_merge(conf, conf_item, file)
      end

      # merge globals
      tools = Sanitize::TOOLS
      %w[before after].each do |pos|
        conf[pos] ||= {}
        tools[:array].each do |key|
          conf[pos][key] ||= []
          conf[pos][key] += conf[key] || []
        end
        tools[:scalar].each do |key|
          conf[pos][key] ||= conf[key] # global can be overriden
        end
      end

      conf
    end

    # Perform one level deep merge on config hashes.
    #
    # @param first [Hash] containing arrays or sub-hashes to be merged
    # @param second [Hash] containing arrays or sub-hashes to be merged
    # @param context_for_error [String] used for reporting merge errors
    def config_merge(first, second, context_for_error = "")
      # merge config files by recursing one level deep
      first.merge!(second) do |key, a, b|
        if Hash === a && Hash === b
          merge(a, b)
        elsif Array === a && Array === b
          a + b
        else
          raise "Error merging configs. Key: #{key}, Context: #{context_for_error}"
        end
      end
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
  end
end

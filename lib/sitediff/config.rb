require 'yaml'

class SiteDiff
  class Config
    def initialize(files)
      @config = {}
      files.each do |file|
        SiteDiff::log "Reading config file: #{file}"
        conf = YAML.load_file(file)

        # support 1 level of recursion via "includes:" key
        if deps = conf.delete("includes")
          deps.each do |dep_file|
            SiteDiff::log "Reading dependent config file: #{dep_file}"
            dep_conf = YAML.load_file(dep_file)
            config_merge(@config, dep_conf)
          end
        end
        config_merge(@config, conf, file)
      end

      @spec = {}
      %w[before after].each { |pos| @spec[pos] = specialize(pos) }
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

    def [](name)
      return @config[name]
    end

    # Specialize a config for either "before" or "after"
    def specialize(name)
      target = {}
      spec = @config[name]
      tools = Util::Sanitize::TOOLS
      tools[:array].each do |key|
        target[key] = []
        target[key] += @config[key] || []
        target[key] += spec[key] || []
      end
      tools[:scalar].each do |key|
        target[key] = @config[key] || spec[key]
      end
      return target
    end

    def before
      @spec['before']
    end
    def after
      @spec['after']
    end

    def paths
      @config["paths"]
    end
  end
end

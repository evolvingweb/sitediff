require 'yaml'

module SiteDiff
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

    def before
      if !@config["before"]
        return @config
      end

      return {
        "dom_transform" => (@config["dom_transform"] || []) + (@config["before"]["dom_transform"] || []),
        "sanitization" => (@config["sanitization"] || []) + (@config["before"]["sanitization"] || []),
        "selector" => @config["before"]["selector"] || @config["selector"]
      }
    end

    def after
      if !@config["after"]
        return @config
      end

      return {
        "dom_transform" => (@config["dom_transform"] || []) + (@config["after"]["dom_transform"] || []),
        "sanitization" => (@config["sanitization"] || []) + (@config["after"]["sanitization"] || []),
        "selector" => @config["after"]["selector"] || @config["selector"]
      }
    end

    def sanitization
      @config["sanitization"]
    end

    def dom_transform
      @config["dom_transform"]
    end

    def paths
      @config["paths"]
    end
  end
end

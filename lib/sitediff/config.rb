require 'yaml'

class SiteDiff
  class Config
    # Contains all configuration for any of before or after: url, url_report,
    # and all the transformation rules defined in Util::Sanitize.
    class Site < Struct.new(:url, :url_report)
      attr_reader :spec
      def initialize(url, url_report, spec)
        super(url, url_report)
        @spec = {}
        tools = Util::Sanitize::TOOLS
        tools[:array].each do |key|
          @spec[key] = spec[key.to_s] || []
        end
        tools[:scalar].each do |key|
          @spec[key] = spec[key.to_s]
        end
      end

    end

    # Reads and merges provided configuration files, fetches dependencies
    # defined via 'include' and overrides configuration, if necessary, by
    # runtime options.
    def initialize(files, run_opts)
      conf = load_conf(files)

      if run_opts['paths_file']
        SiteDiff::log "Reading paths from: #{paths}"
        self.paths = File.readlines(run_opts['paths_file'])
      else
        self.paths = conf['paths']
      end

      @sites = {}
      %w[before after].each do |pos|
        key = pos + '_url'
        url = run_opts[key] || conf[key]

        key = pos + '_url_report'
        url_report = run_opts[key] || conf[key] || url
        @sites[pos] = Site.new(url, url_report, conf[pos])
      end
    end

    def to_s
      # FIXME this creates YAML aliases for concision; hard to read sometimes.
      to_h.to_yaml
    end

    def to_h
      h = {'paths' => @paths, 'before' => {}, 'after' => {}}
      %w[before after].each do |pos|
        h[pos]['url'] = @sites[pos].url
        h[pos]['url_report'] = @sites[pos].url_report
        h[pos]['spec'] = @sites[pos].spec
      end
      h
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
        if deps = conf.delete("includes")
          deps.each do |dep_file|
            SiteDiff::log "Reading dependent config file: #{dep_file}"
            dep_conf = YAML.load_file(dep_file)
            config_merge(conf, dep_conf)
          end
        end
        config_merge(conf, conf_item, file)
      end

      # merge globals
      tools = Util::Sanitize::TOOLS
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

    def before
      @sites['before']
    end
    def after
      @sites['after']
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

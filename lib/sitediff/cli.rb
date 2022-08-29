# frozen_string_literal: true

require 'thor'
require 'sitediff'
require 'sitediff/api'

class SiteDiff
  # SiteDiff CLI.
  class Cli < Thor
    class_option 'directory',
                 type: :string,
                 aliases: '-C',
                 default: 'sitediff',
                 desc: 'Configuration directory'
    class_option :debug,
                 type: :boolean,
                 aliases: '-d',
                 default: false,
                 desc: 'Stop on certain errors and produce error trace backs.'
    class_option 'verbose',
                 type: :boolean,
                 aliases: '-v',
                 default: false,
                 desc: 'Show verbose output in terminal'

    # Command aliases.
    map recrawl: :crawl

    # Thor, by default, exits with 0 no matter what!
    def self.exit_on_failure?
      true
    end

    # Thor, by default, does not raise an error for use of unknown options.
    def self.check_unknown_options?(_config)
      true
    end

    desc 'version', 'Show version information'
    ##
    # Show version information.
    def version
      gemspec = SiteDiff.gemspec
      output = []
      output.push("Sitediff CLI #{gemspec.version}")
      if options[:verbose]
        output.push("Website: #{gemspec.homepage}")
        output.push("GitHub: #{gemspec.metadata['source_code_uri']}")
      end
      puts output.join("\n")
    end

    option 'paths-file',
           type: :string,
           desc: 'Paths are read (one at a line) from PATHS: ' \
                    'useful for iterating over sanitization rules',
           aliases: '--paths-from-file'
    option 'paths',
           type: :array,
           aliases: '-p',
           desc: 'Specific path or paths to fetch'
    option 'before',
           type: :string,
           desc: 'URL to the "before" site, prefixed to all paths.',
           aliases: '--before-url'
    option 'after',
           type: :string,
           desc: 'URL to the "after" site, prefixed to all paths.',
           aliases: '--after-url'
    option 'report-format',
           type: :string,
           enum: %w[html json],
           default: 'html',
           desc: 'The format in which a report should be generated.'
    option 'before-report',
           type: :string,
           desc: 'URL to use in reports. Useful if port forwarding.',
           aliases: '--before-url-report'
    option 'after-report',
           type: :string,
           desc: 'URL to use in reports. Useful if port forwarding.',
           aliases: '--after-url-report'
    option 'cached',
           type: :string,
           enum: %w[none all before after],
           default: 'before',
           desc: 'Use the cached version of these sites, if available.'
    option 'ignore-whitespace',
           type: :boolean,
           default: false,
           aliases: '-w',
           desc: 'Ignore changes in whitespace.'
    option 'export',
           type: :boolean,
           default: false,
           aliases: '-e',
           desc: 'Export report to files. This option forces HTML format.'
    desc 'diff [OPTIONS] [CONFIG-FILE]',
         'Compute diffs on configured URLs.'
    ##
    # Computes diffs.
    def diff(config_file = nil)
      # Determine "paths" override based on options.
      if options['paths'] && options['paths-file']
        SiteDiff.log "Can't specify both --paths-file and --paths.", :error
        exit(-1)
      end

      api = Api.new(options['directory'], config_file)
      api_options =
        clean_keys(
          options,
          :paths,
          :paths_file,
          :ignore_whitespace,
          :export,
          :before,
          :after,
          :cached,
          :verbose,
          :debug,
          :report_format,
          :before_report,
          :after_report
        )
      api_options[:cli_mode] = true
      api.diff(api_options)
    end

    option :port,
           type: :numeric,
           default: SiteDiff::Webserver::DEFAULT_PORT,
           desc: 'The port to serve on'
    option :browse,
           type: :boolean,
           default: true,
           desc: 'Whether to open the served content in your browser'
    desc 'serve [OPTIONS] [CONFIG-FILE]',
         'Serve SiteDiff report directory over HTTP.'
    ##
    # Serves SiteDiff report for accessing in the browser.
    def serve(config_file = nil)
      api = Api.new(options['directory'], config_file)
      api_options = clean_keys(options, :browse, :port)
      api.serve(api_options)
    end

    option :depth,
           type: :numeric,
           default: Config::DEFAULT_CONFIG['settings']['depth'],
           desc: 'How deeply to crawl the given site'
    option :crawl,
           type: :boolean,
           default: true,
           desc: 'Run "sitediff crawl" to discover paths.'
    option :preset,
           type: :string,
           enum: Config::Preset.all,
           desc: 'Framework-specific presets to apply.'
    option :concurrency,
           type: :numeric,
           default: Config::DEFAULT_CONFIG['settings']['concurrency'],
           desc: 'Max number of concurrent connections made.'
    option :interval,
           type: :numeric,
           default: Config::DEFAULT_CONFIG['settings']['interval'],
           desc: 'Crawling delay - interval in milliseconds.'
    option :include,
           type: :string,
           default: Config::DEFAULT_CONFIG['settings']['include'],
           desc: 'Optional URL include regex for crawling.'
    option :exclude,
           type: :string,
           default: Config::DEFAULT_CONFIG['settings']['exclude'],
           desc: 'Optional URL exclude regex for crawling.'
    option :curl_options,
           type: :hash,
           default: {},
           desc: 'Options to be passed to curl'
    desc 'init URL [URL]', 'Create a sitediff configuration.'
    ##
    # Initializes a sitediff (yaml) configuration file.
    def init(*urls)
      unless (1..2).cover? urls.size
        SiteDiff.log 'sitediff init requires one or two URLs', :error
        exit(2)
      end
      api_options =
        clean_keys(
          options,
          :depth,
          :concurrency,
          :interval,
          :include,
          :exclude,
          :preset,
          :crawl
        )
        .merge(
          {
            after_url: urls.pop,
            before_url: urls.pop,
            directory: get_dir(options['directory']),
            curl_opts: get_curl_opts(options)
          }
        )

      Api.init(api_options)
    end

    option :url,
           type: :string,
           desc: 'A custom base URL to fetch from'
    desc 'store [CONFIG-FILE]',
         'Cache the current contents of a site for later comparison.'
    ##
    # Caches the current version of the site.
    def store(config_file = nil)
      api = Api.new(options['directory'], config_file)
      api_options = clean_keys(options, :url, :debug)
      api.store(api_options)
    end

    desc 'crawl [CONFIG-FILE]',
         'Crawl the "before" site to discover paths.'
    ##
    # Crawls the "before" site to determine "paths".
    #
    def crawl(config_file = nil)
      api = Api.new(options['directory'], config_file)
      api.crawl
    end

    no_commands do
      # Generates CURL options.
      #
      # TODO: Possibly move to API class.
      def get_curl_opts(options)
        # We do want string keys here
        bool_hash = { 'true' => true, 'false' => false }
        curl_opts = UriWrapper::DEFAULT_CURL_OPTS
                    .clone
                    .merge(options['curl_options'] || {})
                    .merge(options['curl_opts'] || {})
        curl_opts.each { |k, v| curl_opts[k] = bool_hash.fetch(v, v) }
        curl_opts
      end

      ##
      # Ensures that the given directory exists.
      def get_dir(directory)
        # Create the dir. Must go before cache initialization!
        @dir = Pathname.new(directory || '.')
        @dir.mkpath unless @dir.directory?
        @dir.to_s
      end

      ##
      # Clean keys - return a subset of a hash with keys as symbols.
      def clean_keys(hash, *keys)
        new_hash = hash.transform_keys { |k| k.tr('-', '_').to_sym }
        new_hash.slice(*keys)
      end
    end
  end
end

# frozen_string_literal: true

require 'thor'
require 'sitediff'
require 'sitediff/cache'
require 'sitediff/config'
require 'sitediff/config/creator'
require 'sitediff/config/preset'
require 'sitediff/fetch'
require 'sitediff/webserver/resultserver'

class SiteDiff
  # SiteDiff CLI.
  # TODO: Use config.defaults to feed default values for sitediff.yaml params?
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
        output.push('Website: ' + gemspec.homepage)
        output.push('GitHub: ' + gemspec.metadata['source_code_uri'])
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
    # TODO: Deprecate the parameters before-report / after-report?
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
    desc 'diff [OPTIONS] [CONFIG-FILE]',
         'Compute diffs on configured URLs.'
    ##
    # Computes diffs.
    def diff(config_file = nil)
      @dir = get_dir(options['directory'])
      config = SiteDiff::Config.new(config_file, @dir)

      # Determine "paths" override based on options.
      if options['paths'] && options['paths-file']
        SiteDiff.log "Can't specify both --paths-file and --paths.", :error
        exit(-1)
      end

      # Ignore whitespace option.
      config.ignore_whitespace = options['ignore-whitespace'] if options['ignore-whitespace']

      # Apply "paths" override, if any.
      config.paths = options['paths'] if options['paths']

      # Determine and apply "paths-file", if "paths" is not specified.
      unless options['paths']
        paths_file = options['paths-file']
        paths_file ||= File.join(@dir, Config::DEFAULT_PATHS_FILENAME)
        paths_file = File.expand_path(paths_file)

        paths_count = config.paths_file_read(paths_file)
        SiteDiff.log "Read #{paths_count} paths from: #{paths_file}"
      end

      # TODO: Why do we allow before and after override during diff?
      config.before['url'] = options['before'] if options['before']
      config.after['url'] = options['after'] if options['after']

      # Prepare cache.
      cache = SiteDiff::Cache.new(
        create: options['cached'] != 'none',
        directory: @dir
      )
      cache.read_tags << :before if %w[before all].include?(options['cached'])
      cache.read_tags << :after if %w[after all].include?(options['cached'])
      cache.write_tags << :before << :after

      # Run sitediff.
      sitediff = SiteDiff.new(
        config,
        cache,
        options['verbose'],
        options[:debug]
      )
      num_failing = sitediff.run
      exit_code = num_failing.positive? ? 2 : 0

      # Generate HTML report.
      if options['report-format'] == 'html'
        sitediff.report.generate_html(
          @dir,
          options['before-report'],
          options['after-report']
        )
      end

      # Generate JSON report.
      sitediff.report.generate_json @dir if options['report-format'] == 'json'

      SiteDiff.log 'Run "sitediff serve" to see a report.'
    rescue Config::InvalidConfig => e
      SiteDiff.log "Invalid configuration: #{e.message}", :error
      SiteDiff.log e.backtrace, :error if options[:verbose]
    rescue Config::ConfigNotFound => e
      SiteDiff.log "Invalid configuration: #{e.message}", :error
      SiteDiff.log e.backtrace, :error if options[:verbose]
    else # no exception was raised
      # Thor::Error  --> exit(1), guaranteed by exit_on_failure?
      # Failing diff --> exit(2), populated above
      exit(exit_code)
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
      @dir = get_dir(options['directory'])
      config = SiteDiff::Config.new(config_file, @dir)

      cache = Cache.new(directory: @dir)
      cache.read_tags << :before << :after

      SiteDiff::Webserver::ResultServer.new(
        options[:port],
        options['directory'],
        browse: options[:browse],
        cache: cache,
        config: config
      ).wait
    rescue SiteDiffException => e
      SiteDiff.log e.message, :error
      SiteDiff.log e.backtrace, :error if options[:verbose]
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
    option :whitelist,
           type: :string,
           default: Config::DEFAULT_CONFIG['settings']['whitelist'],
           desc: 'Optional whitelist for crawling.'
    option :blacklist,
           type: :string,
           default: Config::DEFAULT_CONFIG['settings']['blacklist'],
           desc: 'Optional blacklist for crawling.'
    # TODO: Remove this option. Always ignore SSL errors.
    option :insecure,
           type: :boolean,
           default: false,
           desc: 'Ignore many HTTPS/SSL errors'
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

      # Prepare a config object and write it to the file system.
      @dir = get_dir(options['directory'])
      creator = SiteDiff::Config::Creator.new(options[:debug], *urls)
      creator.create(
        depth: options[:depth],
        directory: @dir,
        concurrency: options[:concurrency],
        interval: options[:interval],
        whitelist: Config.create_regexp(options['whitelist']),
        blacklist: Config.create_regexp(options['blacklist']),
        preset: options[:preset],
        curl_opts: get_curl_opts(options)
      )
      SiteDiff.log "Created #{creator.config_file.expand_path}", :success

      # Discover paths, if enabled.
      if options[:crawl]
        crawl(creator.config_file)
        SiteDiff.log 'You can now run "sitediff diff".', :success
      else
        SiteDiff.log 'Run "sitediff crawl" to discover paths. You should then be able to run "sitediff diff".', :info
      end
    end

    option :url,
           type: :string,
           desc: 'A custom base URL to fetch from'
    desc 'store [CONFIG-FILE]',
         'Cache the current contents of a site for later comparison.'
    ##
    # Caches the current version of the site.
    def store(config_file = nil)
      @dir = get_dir(options['directory'])
      config = SiteDiff::Config.new(config_file, @dir)
      # TODO: Figure out how to remove this config.validate call.
      config.validate(need_before: false)
      config.paths_file_read

      cache = SiteDiff::Cache.new(directory: @dir, create: true)
      cache.write_tags << :before

      base = options[:url] || config.after['url']
      fetcher = SiteDiff::Fetch.new(cache,
                                    config.paths,
                                    config.setting(:interval),
                                    config.setting(:concurrency),
                                    get_curl_opts(config.settings),
                                    options[:debug],
                                    before: base)
      fetcher.run do |path, _res|
        SiteDiff.log "Visited #{path}, cached"
      end
    end

    desc 'crawl [CONFIG-FILE]',
         'Crawl the "before" site to discover paths.'
    ##
    # Crawls the "before" site to determine "paths".
    #
    # TODO: Move actual crawling to sitediff.crawl(config).
    # TODO: Switch to paths = sitediff.crawl().
    def crawl(config_file = nil)
      # Prepare configuration.
      @dir = get_dir(options['directory'])
      @config = SiteDiff::Config.new(config_file, @dir)

      # Prepare cache.
      @cache = SiteDiff::Cache.new(
        create: options['cached'] != 'none',
        directory: @dir
      )
      @cache.write_tags << :before << :after

      # Crawl with Hydra to discover paths.
      hydra = Typhoeus::Hydra.new(
        max_concurrency: @config.setting(:concurrency)
      )
      @paths = {}
      @config.roots.each do |tag, url|
        Crawler.new(
          hydra,
          url,
          @config.setting(:interval),
          @config.setting(:whitelist),
          @config.setting(:blacklist),
          @config.setting(:depth),
          get_curl_opts(@config.settings),
          @debug
        ) do |info|
          SiteDiff.log "Visited #{info.uri}, cached."
          after_crawl(tag, info)
        end
      end
      hydra.run

      # Write paths to a file.
      @paths = @paths.values.reduce(&:|).to_a.sort
      @config.paths_file_write(@paths)

      # Log output.
      file = Pathname.new(@dir) + Config::DEFAULT_PATHS_FILENAME
      SiteDiff.log ''
      SiteDiff.log "#{@paths.length} page(s) found."
      SiteDiff.log "Created #{file.expand_path}.", :success, 'done'
    end

    no_commands do
      # Generates CURL options.
      #
      # TODO: This should be in the config class instead.
      # TODO: Make all requests insecure and avoid custom curl-opts.
      def get_curl_opts(options)
        # We do want string keys here
        bool_hash = { 'true' => true, 'false' => false }
        curl_opts = UriWrapper::DEFAULT_CURL_OPTS
                    .clone
                    .merge(options['curl_options'] || {})
                    .merge(options['curl_opts'] || {})
        curl_opts.each { |k, v| curl_opts[k] = bool_hash.fetch(v, v) }
        if options[:insecure]
          curl_opts[:ssl_verifypeer] = false
          curl_opts[:ssl_verifyhost] = 0
        end
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
      # Processes a crawled path.
      def after_crawl(tag, info)
        path = UriWrapper.canonicalize(info.relative)

        # Register the path.
        @paths[tag] = [] unless @paths[tag]
        @paths[tag] << path

        result = info.read_result

        # Write result to applicable cache.
        @cache.set(tag, path, result)
        # If single-site, cache "after" as "before".
        @cache.set(:before, path, result) unless @config.roots[:before]

        # TODO: Restore application of rules.
        # @rules.handle_page(tag, res.content, info.document) if @rules && !res.error
      end
    end
  end
end

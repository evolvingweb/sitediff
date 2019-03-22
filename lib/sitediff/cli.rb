# frozen_string_literal: true

require 'thor'
require 'sitediff'
require 'sitediff/cache'
require 'sitediff/config'
require 'sitediff/config/creator'
require 'sitediff/fetch'
require 'sitediff/webserver/resultserver'

class SiteDiff
  class Cli < Thor
    class_option 'directory',
                 type: :string,
                 aliases: '-C',
                 default: 'sitediff',
                 desc: 'Configuration directory'
    class_option :curl_options,
                 type: :hash,
                 default: {},
                 desc: 'Options to be passed to curl'
    class_option :insecure,
                 type: :boolean,
                 default: false,
                 desc: 'Ignore many HTTPS/SSL errors'
    class_option :debug,
                 type: :boolean,
                 default: false,
                 desc: 'Debug mode. Stop on certain errors and produce a traceback.'
    class_option :interval,
                 type: :numeric,
                 default: 0,
                 desc: 'Crawling delay - interval in milliseconds'

    # Thor, by default, exits with 0 no matter what!
    def self.exit_on_failure?
      true
    end

    # Thor, by default, does not raise an error for use of unknown options.
    def self.check_unknown_options?(_config)
      true
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
           desc: 'URL used to fetch the before HTML. Acts as a prefix to specified paths',
           aliases: '--before-url'
    option 'after',
           type: :string,
           desc: 'URL used to fetch the after HTML. Acts as a prefix to specified paths.',
           aliases: '--after-url'
    option 'before-report',
           type: :string,
           desc: 'Before URL to use for reporting purposes. Useful if port forwarding.',
           aliases: '--before-url-report'
    option 'after-report',
           type: :string,
           desc: 'After URL to use for reporting purposes. Useful if port forwarding.',
           aliases: '--after-url-report'
    option 'cached',
           type: :string,
           enum: %w[none all before after],
           default: 'before',
           desc: 'Use the cached version of these sites, if available.'
    option 'verbose',
           type: :boolean,
           aliases: '-v',
           default: false,
           desc: 'Show differences between versions for each page in terminal'
    option :concurrency,
           type: :numeric,
           default: 3,
           desc: 'Max number of concurrent connections made'
    desc 'diff [OPTIONS] [CONFIGFILES]', 'Perform systematic diff on given URLs'
    def diff(*config_files)
      @interval = options['interval']
      check_interval(@interval)
      @dir = get_dir(options['directory'])
      config = SiteDiff::Config.new(config_files, @dir)

      # override config based on options
      paths = options['paths']
      if (paths_file = options['paths-file'])
        if paths
          SiteDiff.log "Can't have both --paths-file and --paths", :error
          exit(-1)
        end

        paths_file = Pathname.new(paths_file).expand_path
        unless File.exist? paths_file
          raise Config::InvalidConfig,
                "Paths file '#{paths_file}' not found!"
        end
        SiteDiff.log "Reading paths from: #{paths_file}"
        config.paths = File.readlines(paths_file)
      end
      config.paths = paths if paths

      config.before['url'] = options['before'] if options['before']
      config.after['url'] = options['after'] if options['after']

      # Setup cache
      cache = SiteDiff::Cache.new(create: options['cached'] != 'none',
                                  directory: @dir)
      cache.read_tags << :before if %w[before all].include?(options['cached'])
      cache.read_tags << :after if %w[after all].include?(options['cached'])
      cache.write_tags << :before << :after

      sitediff = SiteDiff.new(config, cache, options[:concurrency], @interval,
                              options['verbose'], options[:debug])
      num_failing = sitediff.run(get_curl_opts(options), options[:debug])
      exit_code = num_failing > 0 ? 2 : 0

      sitediff.dump(@dir, options['before-report'],
                    options['after-report'])
    rescue Config::InvalidConfig => e
      SiteDiff.log "Invalid configuration: #{e.message}", :error
      SiteDiff.log "at #{e.backtrace}", :error
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
    desc 'serve [OPTIONS]', 'Serve the sitediff output directory over HTTP'
    def serve(*config_files)
      config = SiteDiff::Config.new(config_files, options['directory'])
      # Could check non-empty config here but currently errors are already raised.

      cache = Cache.new(dir: options['directory'])
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
      SiteDiff.log e.backtrace, :error
    end

    option :depth,
           type: :numeric,
           default: 3,
           desc: 'How deeply to crawl the given site'
    option :rules,
           type: :string,
           enum: %w[yes no disabled],
           default: 'disabled',
           desc: 'Whether rules for the site should be auto-created'
    option :concurrency,
           type: :numeric,
           default: 3,
           desc: 'Max number of concurrent connections made'
    desc 'init URL [URL]', 'Create a sitediff configuration'
    def init(*urls)
      unless (1..2).cover? urls.size
        SiteDiff.log 'sitediff init requires one or two URLs', :error
        exit(2)
      end

      @interval = options['interval']
      check_interval(@interval)
      @dir = get_dir(options['directory'])
      curl_opts = get_curl_opts(options)

      creator = SiteDiff::Config::Creator.new(options[:concurrency],
                                              options['interval'],
                                              curl_opts,
                                              options[:debug],
                                              *urls)
      creator.create(
        depth: options[:depth],
        directory: @dir,
        rules: options[:rules] != 'no',
        rules_disabled: (options[:rules] == 'disabled')
      ) do |_tag, info|
        SiteDiff.log "Visited #{info.uri}, cached"
      end

      SiteDiff.log "Created #{creator.config_file.expand_path}", :success
      SiteDiff.log "You can now run 'sitediff diff'", :success
    end

    option :url,
           type: :string,
           desc: 'A custom base URL to fetch from'
    option :concurrency,
           type: :numeric,
           default: 3,
           desc: 'Max number of concurrent connections made'
    desc 'store [CONFIGFILES]',
         'Cache the current contents of a site for later comparison'
    def store(*config_files)

      @dir = get_dir(options['directory'])
      config = SiteDiff::Config.new(config_files, @dir)
      config.validate(need_before: false)
      cache = SiteDiff::Cache.new(directory: @dir, create: true)
      cache.write_tags << :before

      base = options[:url] || config.after['url']
      fetcher = SiteDiff::Fetch.new(cache, 
                                    config.paths,
                                    options[:interval],
                                    options[:concurrency],
                                    get_curl_opts(options),
                                    options[:debug],
                                    before: base)
      fetcher.run do |path, _res|
        SiteDiff.log "Visited #{path}, cached"
      end
    end

    no_commands do
      def get_curl_opts(options)
        # We do want string keys here
        bool_hash = { 'true' => true, 'false' => false }
        curl_opts = UriWrapper::DEFAULT_CURL_OPTS.clone.merge(options[:curl_options])
        curl_opts.each { |k, v| curl_opts[k] = bool_hash.fetch(v, v) }
        if options[:insecure]
          curl_opts[:ssl_verifypeer] = false
          curl_opts[:ssl_verifyhost] = 0
        end
        curl_opts
      end

      def check_interval(interval)
        if interval != 0 && options[:concurrency] != 1
          SiteDiff.log '--concurrency must be set to 1 in order to enable the interval feature'
          exit(2)
        end
      end

      def get_dir(directory)
        #Create the dir. Must go before cache initialization!
        @dir = Pathname.new(directory || '.')
        @dir.mkpath unless @dir.directory?
        @dir.to_s
      end
    end
  end
end

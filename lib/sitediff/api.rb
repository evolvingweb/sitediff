# frozen_string_literal: true

require 'sitediff'
require 'sitediff/cache'
require 'sitediff/config'
require 'sitediff/config/creator'
require 'sitediff/config/preset'
require 'sitediff/fetch'
require 'sitediff/webserver/resultserver'

class SiteDiff
  ##
  # Sitediff API interface.
  class Api
    ##
    # Initializes new Api object.
    def initialize(directory, config_file = nil)
      @dir = get_dir(directory)
      @config = SiteDiff::Config.new(config_file, @dir)
    end

    ##
    # Intialize a SiteDiff project.
    #
    # Calling:
    #     SiteDiff::Api.init(
    #       depth: 3,
    #       directory: 'sitediff',
    #       concurrency: 3,
    #       interval: 0,
    #       include: nil,
    #       exclude: '*.pdf',
    #       preset: 'drupal',
    #       curl_opts: {timeout: 60},
    #       crawl: false
    #     )
    def self.init(options)
      # Prepare a config object and write it to the file system.
      creator = SiteDiff::Config::Creator.new(options[:debug], options[:before_url], options[:after_url])
      include_regex = Config.create_regexp(options[:include])
      exclude_regex = Config.create_regexp(options[:exclude])
      creator.create(
        depth: options[:depth],
        directory: options[:directory],
        concurrency: options[:concurrency],
        interval: options[:interval],
        include: include_regex,
        exclude: exclude_regex,
        preset: options[:preset],
        curl_opts: options[:curl_opts]
      )
      SiteDiff.log "Created #{creator.config_file.expand_path}", :success

      # TODO: implement crawl ^^^
      # Discover paths, if enabled.
      # if options[:crawl]
      #   crawl(creator.config_file)
      #   SiteDiff.log 'You can now run "sitediff diff".', :success
      # else
      #   SiteDiff.log 'Run "sitediff crawl" to discover paths. You should then be able to run "sitediff diff".', :info
      # end
    end

    ##
    # Diff the `before` and `after`.
    #
    # Calling:
    #     Api.diff(
    #       paths: options['paths'],
    #       paths_file: options['paths-file'],
    #       ignore_whitespace: options['ignore-whitespace'],
    #       export: options['export'],
    #       before: options['before'],
    #       after: options['after'],
    #       cached: options['cached'],
    #       verbose: options['verbose'],
    #       report_format: options['report-format'],
    #       before_report: options['before-report'],
    #       after_report: options['after-report'],
    #       cli_mode: false
    #     )
    def diff(options)
      @config.ignore_whitespace = options[:ignore_whitespace]
      @config.export = options[:export]
      # Apply "paths" override, if any.
      if options[:paths]
        @config.paths = options[:paths]
      else
        paths_file = options[:paths_file]
        paths_file ||= File.join(@dir, Config::DEFAULT_PATHS_FILENAME)
        paths_file = File.expand_path(paths_file)

        paths_count = @config.paths_file_read(paths_file)
        SiteDiff.log "Read #{paths_count} paths from: #{paths_file}"
      end

      # TODO: Why do we allow before and after override during diff?
      @config.before['url'] = options[:before] if options[:before]
      @config.after['url'] = options[:after] if options[:after]

      # Prepare cache.
      cache = SiteDiff::Cache.new(
        create: options[:cached] != 'none',
        directory: @dir
      )
      cache.read_tags << :before if %w[before all].include?(options[:cached])
      cache.read_tags << :after if %w[after all].include?(options[:cached])
      cache.write_tags << :before << :after

      # Run sitediff.
      sitediff = SiteDiff.new(
        @config,
        cache,
        verbose: options[:verbose],
        debug: options[:debug]
      )
      num_failing = sitediff.run
      exit_code = num_failing.positive? ? 2 : 0

      # Generate HTML report.
      if options[:report_format] == 'html' || @config.export
        sitediff.report.generate_html(
          @dir,
          options[:before_report],
          options[:after_report]
        )
      end

      # Generate JSON report.
      if options[:report_format] == 'json' && @config.export == false
        sitediff.report.generate_json @dir
      end

      SiteDiff.log 'Run "sitediff serve" to see a report.' unless options[:export]
    rescue Config::InvalidConfig => e
      SiteDiff.log "Invalid configuration: #{e.message}", :error
      SiteDiff.log e.backtrace, :error if options[:verbose]
    rescue Config::ConfigNotFound => e
      SiteDiff.log "Invalid configuration: #{e.message}", :error
      SiteDiff.log e.backtrace, :error if options[:verbose]
    else # no exception was raised
      # Thor::Error  --> exit(1), guaranteed by exit_on_failure?
      # Failing diff --> exit(2), populated above
      exit(exit_code) if options[:cli_mode]
    end

    ##
    # Crawl the `before` site to determine `paths`.
    def crawl
      # Prepare cache.
      @cache = SiteDiff::Cache.new(
        create: true,
        directory: @dir
      )
      @cache.write_tags << :before << :after

      # Crawl with Hydra to discover paths.
      hydra = Typhoeus::Hydra.new(
        max_concurrency: @config.setting(:concurrency)
      )
      @paths = {}

      ignore_after = @config.roots
      if @config.roots['before'] == @config.roots['after']
        ignore_after.delete('after')
      end

      ignore_after.each do |tag, url|
        Crawler.new(
          hydra,
          url,
          @config.setting(:interval),
          @config.setting(:include),
          @config.setting(:exclude),
          @config.setting(:depth),
          @config.curl_opts,
          debug: @debug
        ) do |info|
          SiteDiff.log "Visited #{info.uri}, cached."
          after_crawl(tag, info)
        end
      end
      hydra.run

      # Write paths to a file.
      @paths = @paths.values.reduce(&:|).to_a.sort
      if @paths.none? | @paths.nil?
        return
      end

      @config.paths_file_write(@paths)

      # Log output.
      file = Pathname.new(@dir) + Config::DEFAULT_PATHS_FILENAME
      SiteDiff.log ''
      SiteDiff.log "#{@paths.length} page(s) found."
      SiteDiff.log "Created #{file.expand_path}.", :success, 'done'
    end

    ##
    # Serves SiteDiff report for accessing in the browser.
    #
    # Calling:
    #     api.serve(browse: true, port: 13080)
    def serve(options)
      @cache = Cache.new(directory: @dir)
      @cache.read_tags << :before << :after

      SiteDiff::Webserver::ResultServer.new(
        options[:port],
        @dir,
        browse: options[:browse],
        cache: @cache,
        config: @config
      ).wait
    rescue SiteDiffException => e
      SiteDiff.log e.message, :error
      SiteDiff.log e.backtrace, :error if options[:verbose]
    end

    ##
    #
    def store(options)
      # TODO: Figure out how to remove this config.validate call.
      @config.validate(need_before: false)
      @config.paths_file_read

      @cache = SiteDiff::Cache.new(directory: @dir, create: true)
      @cache.write_tags << :before

      base = options[:url] || @config.after['url']
      fetcher = SiteDiff::Fetch.new(@cache,
                                    @config.paths,
                                    @config.setting(:interval),
                                    @config.setting(:concurrency),
                                    get_curl_opts(@config.settings),
                                    debug: options[:debug],
                                    before: base)                                   
      fetcher.run do |path, _res|
        SiteDiff.log "Visited #{path}, cached"
      end
    end

    private

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
      # @cache.set(tag, path, result)
      @cache.set(:before, path, result) if tag == 'before'
      @cache.set(:after, path, result) if tag == 'after'

      # TODO: Restore application of rules.
      # @rules.handle_page(tag, res.content, info.document) if @rules && !res.error
    end

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
  end
end

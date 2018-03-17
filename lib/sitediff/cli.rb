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
                 desc: 'Go to a given directory before running.'

    # Thor, by default, exits with 0 no matter what!
    def self.exit_on_failure?
      true
    end

    # Thor, by default, does not raise an error for use of unknown options.
    def self.check_unknown_options?(_config)
      true
    end

    option 'dump-dir',
           type: :string,
           default: File.join('.', 'output'),
           desc: 'Location to write the output to.'
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
    option 'quiet',
           type: :boolean,
           aliases: '-q',
           default: false,
           desc: 'Do not show differences between versions for each page'
    desc 'diff [OPTIONS] [CONFIGFILES]', 'Perform systematic diff on given URLs'
    def diff(*config_files)
      config = chdir(config_files)

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
      cache = SiteDiff::Cache.new(create: options['cached'] != 'none')
      cache.read_tags << :before if %w[before all].include?(options['cached'])
      cache.read_tags << :after if %w[after all].include?(options['cached'])
      cache.write_tags << :before << :after

      sitediff = SiteDiff.new(config, cache, !options['quiet'])
      num_failing = sitediff.run
      exit_code = num_failing > 0 ? 2 : 0

      sitediff.dump(options['dump-dir'], options['before-report'],
                    options['after-report'])
    rescue Config::InvalidConfig => e
      SiteDiff.log "Invalid configuration: #{e.message}", :error
    rescue SiteDiffException => e
      SiteDiff.log e.message, :error
    else # no exception was raised
      # Thor::Error  --> exit(1), guaranteed by exit_on_failure?
      # Failing diff --> exit(2), populated above
      exit(exit_code)
    end

    option :port,
           type: :numeric,
           default: SiteDiff::Webserver::DEFAULT_PORT,
           desc: 'The port to serve on'
    option 'dump-dir',
           type: :string,
           default: 'output',
           desc: 'The directory to serve'
    option :browse,
           type: :boolean,
           default: true,
           desc: 'Whether to open the served content in your browser'
    desc 'serve [OPTIONS]', 'Serve the sitediff output directory over HTTP'
    def serve(*config_files)
      config = chdir(config_files, config: false)

      cache = Cache.new
      cache.read_tags << :before << :after

      SiteDiff::Webserver::ResultServer.new(
        options[:port],
        options['dump-dir'],
        browse: options[:browse],
        cache: cache,
        config: config
      ).wait
    rescue SiteDiffException => e
        SiteDiff.log e.message, :error
    end

    option :output,
           type: :string,
           default: 'sitediff',
           desc: 'Directory in which to place the configuration',
           aliases: ['-o']
    option :depth,
           type: :numeric,
           default: 3,
           desc: 'How deeply to crawl the given site'
    option :rules,
           type: :string,
           enum: %w[yes no disabled],
           default: 'disabled',
           desc: 'Whether rules for the site should be auto-created'
    desc 'init URL [URL]', 'Create a sitediff configuration'
    def init(*urls)
      unless (1..2).cover? urls.size
        SiteDiff.log 'sitediff init requires one or two URLs', :error
        exit 2
      end

      chdir([], search: false)
      creator = SiteDiff::Config::Creator.new(*urls)
      creator.create(
        depth: options[:depth],
        directory: options[:output],
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
    desc 'store [CONFIGFILES]',
         'Cache the current contents of a site for later comparison'
    def store(*config_files)
      config = chdir(config_files)
      config.validate(need_before: false)

      cache = SiteDiff::Cache.new(create: true)
      cache.write_tags << :before

      base = options[:url] || config.after['url']
      fetcher = SiteDiff::Fetch.new(cache, config.paths, before: base)
      fetcher.run do |path, _res|
        SiteDiff.log "Visited #{path}, cached"
      end
    end

    private

    def chdir(files, opts = {})
      opts = { config: true, search: true }.merge(opts)

      dir = options['directory']
      Dir.chdir(dir) if dir

      return unless opts[:search]
      begin
        SiteDiff::Config.new(files, search: !dir)
      rescue SiteDiff::Config::ConfigNotFound
        raise if opts[:config]
        # If no config required, allow it to pass
      end
    end
  end
end

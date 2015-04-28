require 'thor'
require 'sitediff/diff'
require 'sitediff/sanitize'
require 'sitediff/fetch'
require 'sitediff/cache'
require 'sitediff/util/webserver'
require 'sitediff/config/creator'
require 'open-uri'
require 'uri'

class SiteDiff
  class Cli < Thor
    # Thor, by default, exits with 0 no matter what!
    def self.exit_on_failure?
      true
    end

    # Thor, by default, does not raise an error for use of unknown options.
    def self.check_unknown_options?(config)
      true
    end

    option 'dump-dir',
      :type => :string,
      :default => File.join('.', 'output'),
      :desc => "Location to write the output to."
    option 'paths',
      :type => :string,
      :desc => 'Paths are read (one at a line) from PATHS: ' +
               'useful for iterating over sanitization rules',
      :aliases => '--paths-from-file'
    option 'before',
      :type => :string,
      :desc => "URL used to fetch the before HTML. Acts as a prefix to specified paths",
      :aliases => '--before-url'
    option 'after',
      :type => :string,
      :desc => "URL used to fetch the after HTML. Acts as a prefix to specified paths.",
      :aliases => '--after-url'
    option 'before-report',
      :type => :string,
      :desc => "Before URL to use for reporting purposes. Useful if port forwarding.",
      :aliases => '--before-url-report'
    option 'after-report',
      :type => :string,
      :desc => "After URL to use for reporting purposes. Useful if port forwarding.",
      :aliases => '--after-url-report'
    option 'cached',
      :type => :string,
      :enum => %w[none all before after],
      :default => 'before',
      :desc => "Use the cached version of these sites, if available."
    desc "diff [OPTIONS] [CONFIGFILES]", "Perform systematic diff on given URLs"
    def diff(*config_files)
      config = SiteDiff::Config.new(config_files)

      # override config based on options
      if paths_file = options['paths']
        unless File.exists? paths_file
          raise Config::InvalidConfig,
            "Paths file '#{paths_file}' not found!"
        end
        SiteDiff::log "Reading paths from: #{paths_file}"
        config.paths = File.readlines(paths_file)
      end
      config.before['url'] = options['before'] if options['before']
      config.after['url'] = options['after'] if options['after']

      cache = SiteDiff::Cache.new
      cache.write_tags << :before << :after
      cache.read_tags << :before if %w[before all].include?(options['cached'])
      cache.read_tags << :after if %w[after all].include?(options['cached'])

      sitediff = SiteDiff.new(config, cache)
      sitediff.run

      failing_paths = File.join(options['dump-dir'], 'failures.txt')
      sitediff.dump(options['dump-dir'], options['before-report'],
        options['after-report'], failing_paths)
    rescue Config::InvalidConfig => e
      SiteDiff.log "Invalid configuration: #{e.message}", :failure
    end

    option :port,
      :type => :numeric,
      :default => SiteDiff::Util::Webserver::DEFAULT_PORT,
      :desc => 'The port to serve on'
    option :directory,
      :type => :string,
      :default => 'output',
      :desc => 'The directory to serve',
      :aliases => '--dump-dir'
    desc "serve [OPTIONS]", "Serve the sitediff output directory over HTTP"
    def serve
      SiteDiff::Util::Webserver.serve(options[:port], options[:directory],
        :announce => true).wait
    end

    option :directory,
      :type => :string,
      :default => 'sitediff',
      :desc => 'Where to place the configuration',
      :aliases => ['--dir', '--output', '-d']
    option :depth,
      :type => :numeric,
      :default => 3,
      :desc => 'How deeply to crawl the given site'
    desc "init URL [URL]", "Create a sitediff configuration"
    def init(*urls)
      creator = SiteDiff::Config::Creator.new(*urls)
      creator.build(:depth => options[:depth])
      creator.create(:directory => options[:directory])
    end

    option :url,
      :type => :string,
      :desc => 'A custom base URL to fetch from'
    desc "store [CONFIGFILES]",
      "Cache the current contents of a site for later comparison"
    def store(*config_files)
      config = SiteDiff::Config.new(config_files)
      config.validate(:need_before => false)

      cache = SiteDiff::Cache.new
      cache.write_tags << :before

      base = options[:url] || config.after['url']
      fetcher = SiteDiff::Fetch.new(cache, config.paths, :before => base)
      fetcher.run do |path, res|
        puts "Fetched %s" % path
      end
    end
  end
end

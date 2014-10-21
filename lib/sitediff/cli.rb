require 'thor'
require 'sitediff/diff'
require 'sitediff/sanitize'
require 'sitediff/util/webserver'
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
    option 'failing-paths',
      :type => :string,
      :default => File.join('.', 'failures.txt'),
      :desc => 'File in which failing paths are stored (one at a line): ' +
               'useful for iterating over sanitization rules'
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
    option 'cache',
      :type => :string,
      :desc => "Filename to use for caching requests.",
      :lazy_default => 'cache.db'
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

      sitediff = SiteDiff.new(config, options['cache'])
      sitediff.run
      sitediff.dump(options['dump-dir'], options['before-report'],
        options['after-report'], options['failing-paths'])
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
  end
end

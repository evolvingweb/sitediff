require 'thor'
require 'sitediff/util/diff'
require 'sitediff/util/sanitize'
require 'sitediff/util/webserver'
require 'open-uri'
require 'uri'

class SiteDiff
  class Cli < Thor
    # Thor, by default, exits with 0 no matter what!
    def self.exit_on_failure?
      true
    end

    option 'dump-dir',
      :type => :string,
      :default => "./output/",
      :desc => "Location to write the output to."
    option 'paths-from-file',
      :type => :string,
      :desc => "File listing URL paths to run on against <before> and <after> sites.",
      :aliases => '--paths'
    option 'paths-from-failures',
      :type => :boolean,
      :default => FALSE,
      :desc => "Equivalent to --paths-from-file=<DUMPDIR>/failures.txt"
    option 'before-url',
      :type => :string,
      :desc => "URL used to fetch the before HTML. Acts as a prefix to specified paths",
      :aliases => '--before'
    option 'after-url',
      :type => :string,
      :desc => "URL used to fetch the after HTML. Acts as a prefix to specified paths.",
      :aliases => '--after'
    option 'before-url-report',
      :type => :string,
      :desc => "Before URL to use for reporting purposes. Useful if port forwarding."
    option 'after-url-report',
      :type => :string,
      :desc => "After URL to use for reporting purposes. Useful if port forwarding."
      option 'cache',
        :type => :string,
        :desc => "Filename to use for caching requests.",
        :lazy_default => 'cache.db'
    desc "diff [OPTIONS] [CONFIGFILES]", "Perform systematic diff on given URLs"
    def diff(*config_files)
      if options['paths-from-failures']
        SiteDiff::log "Reading paths from failures.txt"
        paths = File.readlines("#{options['dump-dir']}/failures.txt")
      elsif options['paths-from-file']
        SiteDiff::log "Reading paths from file: #{options['paths-from-file']}"
        paths = File.readlines(options['paths-from-file'])
      end

      sitediff = SiteDiff.new(config_files, options['before-url'],
                              options['after-url'], paths, options['cache'])
      sitediff.run

      sitediff.dump(options['dump-dir'], options['before-url-report'],
        options['after-url-report'])
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

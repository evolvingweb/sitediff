# frozen_string_literal: true

require 'sitediff'
require 'sitediff/config'

class SiteDiff
  ##
  # SiteDiff Report Helper.
  class Report
    attr_reader :results, :cache

    ##
    # Directory where diffs will be generated.
    DIFFS_DIR = 'diffs'

    ##
    # Name of file containing a list of pages with diffs.
    FAILURES_FILE = 'failures.txt'

    ##
    # Name of file containing HTML report of diffs.
    REPORT_FILE = 'report.html'

    ##
    # Path to settings used for report.
    SETTINGS_FILE = 'settings.yaml'

    ##
    # Creates a Reporter object.
    #
    # @param [Config] config.
    # @param [Cache] cache.
    # @param [Array] results.
    def initialize(config, cache, results)
      @config = config
      @cache = cache
      @results = results
    end

    ##
    # Generates an HTML report.
    #
    # @param [String] dir
    #   The directory in which the report is to be generated.
    def generate_html(
      dir,
      report_before = nil,
      report_after = nil
    )
      report_before ||= @config.before_url
      report_after ||= @config.after_url

      # Prepare diff directory and wipe out existing diffs.
      dir = Pathname.new(dir)
      dir.mkpath unless dir.directory?
      diff_dir = dir + DIFFS_DIR
      diff_dir.rmtree if diff_dir.exist?

      # Write diffs to the diff directory.
      @results.each { |r| r.dump(dir) if r.status == Result::STATUS_FAILURE }
      SiteDiff.log "All diff files dumped inside #{diff_dir.expand_path}."

      # Store failing paths to failures file.
      failures = dir + FAILURES_FILE
      SiteDiff.log "All failures written to #{failures.expand_path}."
      failures.open('w') do |f|
        @results.each { |r| f.puts r.path unless r.success? }
      end

      # Create report file for each result.
      report = Diff.generate_html(
        @results,
        report_before,
        report_after,
        @cache
      )
      dir.+(REPORT_FILE).open('w') { |f| f.write(report) }

      # Prepare settings file for serving reports.
      # TODO: Find a way to avoid having to create this file.
      settings = {
        'before' => report_before,
        'after' => report_after,
        'cached' => %w[before after]
      }
      dir.+(SETTINGS_FILE).open('w') { |f| YAML.dump(settings, f) }
    end

    ##
    # Returns CSS for HTML report.
    def css
      output = ''
      output += File.read(File.join(SiteDiff::FILES_DIR, 'normalize.css'))
      output += File.read(File.join(SiteDiff::FILES_DIR, 'sitediff.css'))
      output
    end

    ##
    # Returns JS for HTML report.
    def js
      output = ''
      output += File.read(File.join(SiteDiff::FILES_DIR, 'jquery.min.js'))
      output += File.read(File.join(SiteDiff::FILES_DIR, 'sitediff.js'))
      output
    end
  end
end

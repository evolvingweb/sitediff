# frozen_string_literal: true

require 'json'
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
    REPORT_FILE_HTML = 'report.html'

    ##
    # Name of file containing JSON report of diffs.
    REPORT_FILE_JSON = 'report.json'

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

      dir = SiteDiff.ensure_dir dir

      write_diffs dir
      write_failures dir

      # Prepare report.
      report = Diff.generate_html(
        @results,
        report_before,
        report_after,
        @cache
      )

      # Write report.
      report_file = dir + REPORT_FILE_HTML
      report_file.unlink if report_file.file?
      report_file.open('w') { |f| f.write(report) }

      write_settings dir, report_before, report_after

      SiteDiff.log 'Report generated to ' + report_file.expand_path.to_s
    end

    ##
    # Generates a JSON report.
    #
    # @param dir
    #   The directory in which the report is to be generated.
    def generate_json(dir)
      dir = SiteDiff.ensure_dir dir
      report_before = nil
      report_after = nil

      write_diffs dir
      write_failures dir

      # Prepare report.
      report = {
        paths_compared: @results.length,
        paths_diffs: 0,
        paths: {}
      }
      @results.each do |item|
        report[:paths_diffs] += 1 unless item.success?

        item_report = {
          path: item.path,
          status: item.status,
          message: item.error
        }
        report[:paths][item.path] = item_report
      end
      report = JSON report

      # Write report.
      report_file = dir + REPORT_FILE_JSON
      report_file.unlink if report_file.file?
      report_file.open('w') { |f| f.write(report) }

      write_settings dir

      SiteDiff.log 'Report generated to ' + report_file.expand_path.to_s
    end

    ##
    # Creates diff files in a directory named "diffs".
    #
    # If "dir" is /foo/bar, then diffs will be placed in /foo/bar/diffs.
    #
    # @param [Pathname] dir
    #   The directory in which a "diffs" directory is to be generated.
    def write_diffs(dir)
      raise Exception 'dir must be a Pathname' unless dir.is_a? Pathname

      # Delete existing "diffs" dir, if exists.
      diff_dir = dir + DIFFS_DIR
      diff_dir.rmtree if diff_dir.exist?

      # Write diffs to the diff directory.
      @results.each { |r| r.dump(dir) if r.status == Result::STATUS_FAILURE }
      SiteDiff.log "All diff files written to #{diff_dir.expand_path}"
    end

    ##
    # Writes paths with diffs into a file.
    #
    # @param [Pathname] dir
    #   The directory in which the report is to be generated.
    def write_failures(dir)
      raise Exception 'dir must be a Pathname' unless dir.is_a? Pathname

      failures = dir + FAILURES_FILE
      SiteDiff.log "All failures written to #{failures.expand_path}"
      failures.open('w') do |f|
        @results.each { |r| f.puts r.path unless r.success? }
      end
    end

    ##
    # Creates report settings.yaml file.
    #
    # TODO: Find a way to avoid having to create this file.
    #
    # @param [Pathname] dir
    #   The directory in which the report is to be generated.
    def write_settings(dir, report_before = nil, report_after = nil)
      raise Exception 'dir must be a Pathname' unless dir.is_a? Pathname

      settings = {
        'before' => report_before,
        'after' => report_after,
        'cached' => %w[before after]
      }
      dir.+(SETTINGS_FILE).open('w') { |f| YAML.dump(settings, f) }
    end

    ##
    # Returns CSS for HTML report.
    def self.css
      output = ''
      output += File.read(File.join(SiteDiff::FILES_DIR, 'normalize.css'))
      output += File.read(File.join(SiteDiff::FILES_DIR, 'sitediff.css'))
      output
    end

    ##
    # Returns JS for HTML report.
    def self.js
      output = ''
      output += File.read(File.join(SiteDiff::FILES_DIR, 'jquery.min.js'))
      output += File.read(File.join(SiteDiff::FILES_DIR, 'sitediff.js'))
      output
    end
  end
end

#!/bin/env ruby
# frozen_string_literal: true

require 'sitediff/config'
require 'sitediff/fetch'
require 'sitediff/result'
require 'pathname'
require 'rainbow'
require 'yaml'

class SiteDiff
  # path to misc. static files (e.g. erb, css files)
  FILES_DIR = File.join(File.dirname(__FILE__), 'sitediff', 'files')

  # subdirectory containing all failing diffs
  DIFFS_DIR = 'diffs'

  # files in output
  FAILURES_FILE = 'failures.txt'
  REPORT_FILE = 'report.html'
  SETTINGS_FILE = 'settings.yaml'

  # label will be colorized and str will not be.
  # type dictates the color: can be :success, :error, or :failure
  def self.log(str, type = :info, label = nil)
    label = label ? "[sitediff] #{label}" : '[sitediff]'
    bg = fg = nil
    case type
    when :info
      bg = fg = nil
    when :diff_success
      bg = :green
      fg = :black
    when :diff_failure
      bg = :red
    when :warn
      bg = :yellow
      fg = :black
    when :error
      bg = :red
    end
    label = Rainbow(label)
    label = label.bg(bg) if bg
    label = label.fg(fg) if fg
    puts label + ' ' + str
  end

  attr_reader :config, :results
  def before
    @config.before['url']
  end

  def after
    @config.after['url']
  end

  def initialize(config, cache, concurrency, verbose = true)
    @cache = cache
    @verbose = verbose

    # Check for single-site mode
    validate_opts = {}
    if !config.before['url'] && @cache.tag?(:before)
      unless @cache.read_tags.include?(:before)
        raise SiteDiffException,
              "A cached 'before' is required for single-site mode"
      end
      validate_opts[:need_before] = false
    end
    config.validate(validate_opts)

    @concurrency = concurrency
    @config = config
  end

  # Sanitize HTML
  def sanitize(path, read_results)
    %i[before after].map do |tag|
      html = read_results[tag].content
      config = @config.send(tag)
      Sanitizer.new(html, config, path: path).sanitize
    end
  end

  # Process a set of read results
  def process_results(path, read_results)
    diff = if (error = (read_results[:before].error || read_results[:after].error))
             Result.new(path, nil, nil, error)
           else
             Result.new(path, *sanitize(path, read_results), nil)
           end
    @results[path] = diff

    # Print results in order!
    while (next_diff = @results[@ordered.first])
      next_diff.log(@verbose)
      @ordered.shift
    end
  end

  # Perform the comparison, populate @results and return the number of failing
  # paths (paths with non-zero diff).
  def run
    # Map of path -> Result object, populated by process_results
    @results = {}
    @ordered = @config.paths.dup

    unless @cache.read_tags.empty?
      SiteDiff.log('Using sites from cache: ' +
        @cache.read_tags.sort.join(', '))
    end

    # TODO: Fix this after config merge refactor!
    # Not quite right. We are not passing @config.before or @config.after
    # so passing this instead but @config.after['curl_opts'] is ignored.
    curl_opts = @config.before['curl_opts']
    fetcher = Fetch.new(@cache, @config.paths, @concurrency, curl_opts,
                        before: before, after: after)
    fetcher.run(&method(:process_results))

    # Order by original path order
    @results = @config.paths.map { |p| @results[p] }
    results.map { |r| r unless r.success? }.compact.length
  end

  # Dump results to disk
  def dump(dir, report_before, report_after)
    report_before ||= before
    report_after ||= after
    dir = Pathname.new(dir)
    dir.mkpath unless dir.directory?

    # store diffs of each failing case, first wipe out existing diffs
    diff_dir = dir + DIFFS_DIR
    diff_dir.rmtree if diff_dir.exist?
    results.each { |r| r.dump(dir) if r.status == Result::STATUS_FAILURE }
    SiteDiff.log "All diff files were dumped inside #{dir.expand_path}"

    # store failing paths
    failures = dir + FAILURES_FILE
    SiteDiff.log "Writing failures to #{failures.expand_path}"
    failures.open('w') do |f|
      results.each { |r| f.puts r.path unless r.success? }
    end

    # create report of results
    report = Diff.generate_html_report(results, report_before, report_after,
                                       @cache)
    dir.+(REPORT_FILE).open('w') { |f| f.write(report) }

    # serve some settings
    settings = { 'before' => report_before, 'after' => report_after,
                 'cached' => @cache.read_tags.map(&:to_s) }
    dir.+(SETTINGS_FILE).open('w') { |f| YAML.dump(settings, f) }
  end
end

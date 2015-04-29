#!/bin/env ruby
require 'sitediff/cli.rb'
require 'sitediff/config.rb'
require 'sitediff/result.rb'
require 'sitediff/uriwrapper'
require 'sitediff/cache'
require 'sitediff/fetch'
require 'typhoeus'
require 'rainbow'

class SiteDiff
  # path to misc. static files (e.g. erb, css files)
  FILES_DIR = File.join(File.dirname(__FILE__), 'sitediff', 'files')

  # subdirectory containing all failing diffs
  DIFFS_DIR = 'diffs'

  # label will be colorized and str will not be.
  # type dictates the color: can be :success, :error, or :failure
  def self.log(str, type=:info, label=nil)
    label = label ? "[sitediff] #{label}" : '[sitediff]'
    bg = fg = nil
    case type
    when :info
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

  def initialize(config, cache, verbose=true)
    @cache = cache
    @verbose = verbose

    # Check for single-site mode
    validate_opts = {}
    if @cache.tag?(:before) && !config.before['url']
      validate_opts[:need_before] = false
      cache.read_tags << :before
    end

    @config = config
  end

  # Sanitize an HTML string based on configuration for either before or after
  def sanitize(html, pos)
    Sanitize::sanitize(html, @config.send(pos))
  end

  # Process a set of read results
  def process_results(path, read_results)
    if error = read_results[:before].error || read_results[:after].error
      diff = Result.new(path, nil, nil, error)
    else
      diff = Result.new(path, sanitize(read_results[:before].content, :before),
                        sanitize(read_results[:after].content,:after), nil)
    end
    diff.log(@verbose)
    @results[path] = diff
  end

  # Perform the comparison, populate @results and return the number of failing
  # paths (paths with non-zero diff).
  def run
    # Map of path -> Result object, populated by process_results
    @results = {}

    unless @cache.read_tags.empty?
      SiteDiff.log("Using sites from cache: " +
        @cache.read_tags.sort.join(', '))
    end

    fetcher = Fetch.new(@cache, @config.paths,
      :before => before, :after => after)
    fetcher.run(&self.method(:process_results))

    # Order by original path order
    @results = @config.paths.map { |p| @results[p] }
    return results.map{ |r| r unless r.success? }.compact.length
  end

  # Dump results to disk
  def dump(dir, report_before, report_after, failing_paths)
    report_before ||= before
    report_after ||= after
    FileUtils.mkdir_p(dir)

    # store diffs of each failing case, first wipe out existing diffs
    diff_dir = File.join(dir, DIFFS_DIR)
    FileUtils.rm_rf(diff_dir)
    results.each { |r| r.dump(dir) if r.status == Result::STATUS_FAILURE }
    SiteDiff::log "All diff files were dumped inside #{dir}"

    # store failing paths
    SiteDiff::log "Writing failures to #{failing_paths}"
    File.open(failing_paths, 'w') do |f|
      results.each { |r| f.puts r.path unless r.success? }
    end

    # create report of results
    report = Diff::generate_html_report(results, report_before, report_after)
    File.open(File.join(dir, "/report.html") , 'w') { |f| f.write(report) }
  end
end

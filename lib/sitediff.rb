#!/bin/env ruby
require 'sitediff/cli.rb'
require 'sitediff/config.rb'
require 'sitediff/result.rb'
require 'sitediff/uriwrapper'
require 'sitediff/util/cache'
require 'typhoeus'
require 'rainbow'

class SiteDiff
  # path to misc. static files (e.g. erb, css files)
  FILES_DIR = File.join(File.dirname(__FILE__), 'sitediff', 'files')

  # subdirectory containing all failing diffs
  DIFFS_DIR = 'diffs'

  # label will be colorized and str will not be.
  # type dictates the color: can be :success, :error, or :failure
  def self.log(str, type=nil, label=nil)
    label = label ? "[sitediff] #{label}" : '[sitediff]'
    bg = fg = nil
    case type
    when :success
      bg = :green
      fg = :black
    when :failure
      bg = :red
    when :error
      bg = :yellow
      fg = :black
    end
    label = Rainbow(label)
    label = label.bg(bg) if bg
    label = label.fg(fg) if fg
    puts label + ' ' + str
  end

  attr_accessor :before, :after, :config, :results
  def before
    @config.before.url
  end
  def after
    @config.after.url
  end

  def cache=(file)
    # FIXME: Non-global cache would be nice
    return unless file
    if Gem::Version.new(Typhoeus::VERSION) >= Gem::Version.new('0.6.4')
      Typhoeus::Config.cache = SiteDiff::Util::Cache.new(file)
    else
      # Bug, see: https://github.com/typhoeus/typhoeus/pull/296
      SiteDiff::log("Cache unsupported on Typhoeus version < 0.6.4", :failure)
    end
  end

  def initialize(config, cache)
    config.validate
    @config = config
    self.cache = cache
  end

  # Sanitize an HTML string based on configuration for either before or after
  def sanitize(html, pos)
    Sanitize::sanitize(html, @config.send(pos).spec)
  end

  # Queues fetching before and after URLs with a Typhoeus::Hydra instance
  #
  # Upon completion of both before and after, prints and saves the diff to
  # @results.
  def queue_read(hydra, path)
    # ( :before | after ) => ReadResult object
    reads = {}
    [:before, :after].each do |pos|
      uri = UriWrapper.new(send(pos) + path)

      uri.queue(hydra) do |res|
        reads[pos] = res
        next unless reads.size == 2

        # we have read both before and after; calculate diff
        if error = reads[:before].error || reads[:after].error
          diff = Result.new(path, nil, nil, error)
        else
          diff = Result.new(path, sanitize(reads[:before].content, :before),
                            sanitize(reads[:after].content,:after), nil)
        end
        diff.log
        @results[path] = diff
      end
    end
  end

  # Perform the comparison
  def run
    # Map of path -> Result object, queue_read sets callbacks to populate this
    @results = {}

    hydra = Typhoeus::Hydra.new(max_concurrency: 3)
    @config.paths.each { |path| queue_read(hydra, path) }
    hydra.run

    # Order by original path order
    @results = @config.paths.map { |p| @results[p] }
  end

  # Dump results to disk
  def dump(dir, report_before, report_after, failing_paths)
    report_before ||= before
    report_after ||= after
    FileUtils.mkdir_p(dir)

    # dump output of each failure
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

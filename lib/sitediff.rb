#!/bin/env ruby
require 'sitediff/cli.rb'
require 'sitediff/config.rb'
require 'sitediff/result.rb'
require 'sitediff/util/uriwrapper'
require 'typhoeus'

class SiteDiff
  # see here for color codes: http://bluesock.org/~willkg/dev/ansi.html
  def self.log(str)
    puts "[sitediff] #{str}"
  end

  def self.log_yellow(str)
    puts "\033[0;33m[sitediff] #{str}\033[00m"
  end

  def self.log_red(str)
    puts "\033[0;31m[sitediff] #{str}\033[00m"
  end

  def self.log_red_background(str)
    puts "\033[0;41m[sitediff] #{str}\033[00m"
  end

  def self.log_green_background(str)
    puts "\033[0;42;30m[sitediff] #{str}\033[00m"
  end

  def self.log_yellow_background(str)
    puts "\033[0;43;30m[sitediff] #{str}\033[00m"
  end

  def self.log_green(str)
    puts "\033[0;32m[sitediff] #{str}\033[00m"
  end

  def diff_path(path, before_html, after_html, error)
    before_url = before + path
    before_html_sanitized = Util::Sanitize::sanitize(before_html, @config.before).join("\n")
    after_html_sanitized = Util::Sanitize::sanitize(after_html, @config.after).join("\n")

    result = Result.new(path, before_html_sanitized, after_html_sanitized,
      error)
    return result
  end

  attr_accessor :before, :after, :paths, :results

  def before=(url)
    @before = Util::UriWrapper.new(url)
  end
  def after=(url)
    @after = Util::UriWrapper.new(url)
  end

  def paths=(paths)
    @paths = paths.map { |p| p.chomp }
  end
  def paths
    defined?(@paths) ? @paths : @config.paths
  end

  def initialize(config_files)
    @config = Config.new(config_files)
  end

  # Queue a path for reading
  def queue(q, path)
    reads = @read_results[path] = {}
    [:before, :after].each do |pos| # Read both before and after urls
      uri = send(pos) + path
      uri.queue(q) do |read_result|
        reads[pos] = read_result
        try_complete(path, reads) # See if we can complete this path
      end
    end
  end

  # Attempt to finish processing this path
  def try_complete(path, reads)
    return unless reads.size == 2 # We need both before and after

    error = reads[:before].error || reads[:after].error
    result = diff_path(path, reads[:before].content, reads[:after].content,
      error)
    result.log
    @results_by_path[path] = result
  end

  # Perform the comparison
  def run
    @results_by_path = {}
    @read_results = {}
    hydra = Typhoeus::Hydra.new(max_concurrency: 3)
    paths.each { |p| queue(hydra, p) }
    hydra.run

    # Order by original path order
    @results = paths.map { |p| @results_by_path[p] }
  end

  # Dump results to disk
  def dump(dir, before_report, after_report)
    before_report ||= before.to_s
    after_report ||= after.to_s

    # dump output of each failure
    results.each { |r| r.dump(dir) if r.status == Result::STATUS_FAILURE }

    # log failing paths to failures.txt
    non_success = results.select { |r| !r.success? }
    if non_success
      failures_path = File.join(dir, "/failures.txt")
      SiteDiff::log "Writing failures to #{failures_path}"
      File.open(failures_path, 'w') do |f|
        non_success.each { |r| f.puts r.path }
      end
    end

    # create report of results
    report = Util::Diff::generate_html_report(results,
      before_report, after_report)
    File.open(File.join(dir, "/report.html") , 'w') { |f| f.write(report) }

    SiteDiff::log_yellow "All diff files were dumped inside #{dir}"
  end
end

#!/bin/env ruby
require 'sitediff/cli.rb'
require 'sitediff/config.rb'
require 'sitediff/result.rb'
require 'sitediff/util/uriwrapper'

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

  def diff_path(path)
    before_url = before + path
    after_url = after + path
    error = nil
    begin
      before_html = before_url.read
      after_html  = after_url.read
    rescue SiteDiffReadFailure => e
      error = e.message
    end

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

  # Perform the comparison
  def run
    @results = []
    paths.each do |p|
      p.chomp!
      result = diff_path(p)
      result.log
      @results << result
    end
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

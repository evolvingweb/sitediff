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
    path.chomp!
    before_url = URI::encode(before.to_s + "/" + path)
    after_url = URI::encode(after.to_s + "/" + path)
    before_params = {
      :http_basic_authentication => [before.user, before.password]
    }
    after_params = {
      :http_basic_authentication => [after.user, after.password]
    }

    error = nil
    begin
      before_html = Util::IO::read(before_url, before_params)
      after_html  = Util::IO::read(after_url, after_params)
    rescue SiteDiffReadFailure => e
      error = e.message
    end

    before_html_sanitized = Util::Sanitize::sanitize(before_html, @config.before).join("\n")
    after_html_sanitized = Util::Sanitize::sanitize(after_html, @config.after).join("\n")

    result = Result.new(path, before_html_sanitized, after_html_sanitized)
    result.log
    result.dump(dump_dir) if result.status == Result::STATUS_FAILURE
    return result
  end

  attr_accessor :before, :after, :before_url_report, :after_url_report,
    :paths, :dump_dir

  def before=(url)
    @before = Util::UriWrapper.new(url)
  end
  def after=(url)
    @after = Util::UriWrapper.new(url)
  end

  def before_url_report
    return @before_url_report if defined?(@before_url_report) &&
      !@before_url_report.empty?
    return before
  end
  def after_url_report
    return @after_url_report if defined?(@after_url_report) &&
      !@after_url_report.empty?
    return after
  end

  def paths
    defined?(@paths) ? @paths : @config.paths
  end

  def initialize(config_files)
    @config = Config.new(config_files)
  end

  def run
    results = []
    paths.each do |path|
      results << diff_path(path)
    end

    # log failing paths to failures.txt
    failures = results.collect { |r| r.path if r.success? }.compact().join("\n")
    if failures
      failures_path = File.join(dump_dir, "/failures.txt")
      SiteDiff::log "Writing failures to #{failures_path}"
      File.open(failures_path, 'w') { |f| f.write(failures) }
    end

    report = Util::Diff::generate_html_report(results, before_url_report, after_url_report)
    File.open(File.join(dump_dir, "/report.html") , 'w') { |f| f.write(report) }

    SiteDiff::log_yellow "All diff files were dumped inside #{dump_dir}"
  end
end

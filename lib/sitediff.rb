#!/bin/env ruby
require 'sitediff/cli.rb'
require 'sitediff/config.rb'

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
    result = {}
    result[:path] = path.chomp
    result[:before_url] = URI::encode(@before.to_s + "/" + result[:path])
    result[:after_url] =  URI::encode(@after.to_s + "/" + result[:path])
    result[:before_url_report] = @before_url_report.to_s + "/" + result[:path]
    result[:after_url_report] =  @after_url_report.to_s + "/" + result[:path]
    before_params = {
      :http_basic_authentication => [@before.user, @before.password]
    }
    after_params = {
      :http_basic_authentication => [@after.user, @after.password]
    }
    begin
      result[:before_html] = SiteDiff::Util::IO::read(result[:before_url], before_params)
      result[:after_html]  = SiteDiff::Util::IO::read(result[:after_url], after_params)
    rescue SiteDiffReadFailure => e
      result[:error] = e.message
    end

    result[:before_html_sanitized] = SiteDiff::Util::Sanitize::sanitize(result[:before_html], @config.before).join("\n")
    result[:after_html_sanitized] = SiteDiff::Util::Sanitize::sanitize(result[:after_html], @config.after).join("\n")
    result[:html_diff] = SiteDiff::Util::Diff::html_diffy(result[:before_html_sanitized], result[:after_html_sanitized])
    result[:filename] = "diff_" + result[:path].gsub('/', '_').gsub('#', '___') + ".html"
    result[:filepath] = File.join(@dump_dir, result[:filename])
    result[:status] = result[:error] ? "error" : result[:html_diff] ? "failure" : "success"

    if result[:status] == "success"
      SiteDiff::log_green_background "SUCCESS: #{result[:path]}"
    elsif result[:error]
      SiteDiff::log_yellow_background "ERROR (#{result[:error]}): #{result[:path]}"
    else
      SiteDiff::log_red_background "FAILURE: #{result[:path]}"
      puts SiteDiff::Util::Diff::terminal_diffy(result[:before_html_sanitized], result[:after_html_sanitized])
      File.open(result[:filepath], 'w') { |f| f.write(SiteDiff::Util::Diff::generate_diff_output(result)) }
    end
    return result
  end

  def initialize(options, config_files)
    @before = SiteDiff::UriWrapper.new(options['before-url'])
    @after = SiteDiff::UriWrapper.new(options['after-url'])

    @config = SiteDiff::Config.new(config_files)

    if options['paths-from-failures']
      SiteDiff::log "Reading paths from failures.txt"
      @paths = File.readlines("#{options['dump-dir']}/failures.txt")
    elsif options['paths-from-file']
      SiteDiff::log "Reading paths from file: #{options['paths-from-file']}"
      @paths = File.readlines(options['paths-from-file'])
    elsif @config.paths
      SiteDiff::log "Reading paths from config"
      @paths = @config.paths
    end

    # default report URLs to actual URLs
    @before_url_report = options['before-url-report'].empty? ? @before :
      options['before-url-report']
    @after_url_report = options['after-url-report'].empty? ? @after :
      options['after-url-report']

    @dump_dir = options['dump-dir']
  end

  def run
    results = []
    @paths.each do |path|
      results << diff_path(path)
    end

    # log failing paths to failures.txt
    failures = results.collect { |r| r[:path] if r[:status] != "success" }.compact().join("\n")
    if failures
      failures_path = File.join(@dump_dir, "/failures.txt")
      SiteDiff::log "Writing failures to #{failures_path}"
      File.open(failures_path, 'w') { |f| f.write(failures) }
    end

    report = SiteDiff::Util::Diff::generate_html_report(results, @before_url_report, @after_url_report)
    File.open(File.join(@dump_dir, "/report.html") , 'w') { |f| f.write(report) }

    SiteDiff::log_yellow "All diff files were dumped inside #@dump_dir}"
  end
end

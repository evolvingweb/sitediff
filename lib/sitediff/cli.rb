require 'thor'
require 'sitediff/util/diff'
require 'sitediff/util/sanitize'
require 'open-uri'

module SiteDiff
  class Cli < Thor
    # Thor, by default, exits with 0 no matter what!
    def self.exit_on_failure?
      true
    end

    option 'dump-dir',
      :type => :string,
      :default => "./output/",
      :banner => "Location to write the output to."
    option 'paths-from-file',
      :type => :string,
      :banner => "File listing URL paths to run on against <before> and <after> sites."
    option 'paths-from-failures',
      :type => :boolean,
      :default => FALSE,
      :banner => "Equivalent to --paths-from-file=<DUMPDIR>/failures.txt"
    option 'before-url',
      :required => true,
      :type => :string,
      :banner => "URL used to fetch the before HTML. Acts as a prefix to specified paths"
    option 'after-url',
      :required => true,
      :type => :string,
      :banner => "URL used to fetch the after HTML. Acts as a prefix to specified paths."
    option 'before-url-report',
      :type => :string,
      :default => "",
      :banner => "Before URL to use for reporting purposes. Useful if port forwarding."
    option 'after-url-report',
      :type => :string,
      :default => "",
      :banner => "After URL to use for reporting purposes. Useful if port forwarding."
    desc "diff [OPTIONS] <BEFORE> <AFTER> [CONFIGFILES]", "Perform systematic diff on given URLs"
    def diff(*config_files)
      before = options['before-url']
      after = options['after-url']
      config = SiteDiff::Config.new(config_files)

      differences = Array.new

      if options['paths-from-failures']
        SiteDiff::log "Reading paths from failures.txt"
        paths = File.readlines("#{options['dump-dir']}/failures.txt")
      elsif options['paths-from-file']
        SiteDiff::log "Reading paths from file: #{options['paths-from-file']}"
        paths = File.readlines(options['paths-from-file'])
      elsif config.paths
        SiteDiff::log "Reading paths from config"
        paths = config.paths
      end

      # default report URLs to actual URLs
      options['before-url-report'] ||= before
      options['after-url-report'] ||= after

      results = []

      paths.each do |path|
        result = {}
        result[:path] = path.chomp
        result[:before_url] = URI::encode(before + "/" + result[:path])
        result[:after_url] =  URI::encode(after + "/" + result[:path])
        result[:before_url_report] = options['before-url-report'] + "/" + result[:path]
        result[:after_url_report] =  options['after-url-report'] + "/" + result[:path]

        begin
          result[:before_html] = open(result[:before_url])
        rescue OpenURI::HTTPError => e
          result[:error] = "BEFORE: " + e.message
        end

        begin
          result[:after_html] = open(result[:after_url])
        rescue OpenURI::HTTPError => e
          result[:error] = "AFTER: " + e.message
        end

        result[:before_html_sanitized] = SiteDiff::Util::Sanitize::sanitize(result[:before_html], config.before).join("\n")
        result[:after_html_sanitized] = SiteDiff::Util::Sanitize::sanitize(result[:after_html], config.after).join("\n")
        result[:html_diff] = SiteDiff::Util::Diff::html_diffy(result[:before_html_sanitized], result[:after_html_sanitized])
        result[:filename] = "diff_" + result[:path].gsub('/', '_').gsub('#', '___') + ".html"
        result[:filepath] = File.join(options['dump-dir'], result[:filename])
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
        results << result
      end

      # log failing paths to failures.txt
      failures = results.collect { |r| r[:path] if !r[:status] }.compact().join("\n")
      if failures
        failures_path = File.join(options['dump-dir'], "/failures.txt")
        SiteDiff::log "Writing failures to #{failures_path}"
        File.open(failures_path, 'w') { |f| f.write(failures) }
      end

      report = SiteDiff::Util::Diff::generate_html_report(results, options['before-url-report'], options['after-url-report'])
      File.open(File.join(options['dump-dir'], "/report.html") , 'w') { |f| f.write(report) }

      SiteDiff::log_yellow "All diff files were dumped inside #{options['dump-dir']}"
    end
  end
end

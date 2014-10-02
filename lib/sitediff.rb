#!/bin/env ruby
require 'sitediff/cli.rb'
require 'sitediff/config.rb'
require 'sitediff/result.rb'
require 'sitediff/util/uriwrapper'
require 'sitediff/util/cache'
require 'typhoeus'
require 'rainbow'

class SiteDiff
  def self.log(str, bg = nil, fg = nil)
    str = Rainbow("[sitediff] #{str}")
    str = str.bg(bg) if bg
    str = str.send(fg) if fg
    puts str
  end

  attr_accessor :before, :after, :paths, :results
  def before
    Util::UriWrapper.new(@before || @config['before_url'])
  end
  def after
    Util::UriWrapper.new(@after || @config['after_url'])
  end

  def paths=(paths)
    paths ||= ['']
    @paths = paths.map { |p| p.chomp }
  end
  def paths
    defined?(@paths) ? @paths : @config.paths
  end

  def cache=(file)
    # FIXME: Non-global cache would be nice
    return unless file
    if Gem::Version.new(Typhoeus::VERSION) >= Gem::Version.new('0.6.4')
      Typhoeus::Config.cache = SiteDiff::Util::Cache.new(file)
    else
      # Bug, see: https://github.com/typhoeus/typhoeus/pull/296
      SiteDiff::log("Cache unsupported on Typhoeus version < 0.6.4", :red)
    end
  end

  def initialize(config_files, before, after, paths, cache)
    @config = Config.new(config_files)
    self.before = before
    self.after = after
    self.paths = paths if paths
    self.cache = cache
  end

  # Sanitize an HTML string based on configuration for either before or after
  def sanitize(html, pos)
    Util::Sanitize::sanitize(html, @config.send(pos))
  end

  # Queues fetching before and after URLs with a Typhoeus::Hydra instance
  #
  # Upon completion of both before and after, prints and saves the diff to
  # @results.
  def queue_read(hydra, path)
    # ( :before | after ) => ReadResult object
    reads = {}
    [:before, :after].each do |pos|
      uri = send(pos) + path # new UriWrapper object with new URI string

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
    paths.each { |path| queue_read(hydra, path) }
    hydra.run

    # Order by original path order
    @results = paths.map { |p| @results[p] }
  end

  # Dump results to disk
  def dump(dir, before_report, after_report)
    before_report ||= @config['before_url_report'] || before.to_s
    after_report ||= @config['after_url_report'] || after.to_s

    FileUtils.mkdir_p(dir)

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

    SiteDiff::log "All diff files were dumped inside #{dir}", :yellow, :black
  end
end

#!/bin/env ruby
# frozen_string_literal: true

require 'sitediff/config'
require 'sitediff/diff'
require 'sitediff/fetch'
require 'sitediff/result'
require 'sitediff/report'
require 'pathname'
require 'rainbow'
require 'rubygems'
require 'yaml'

# SiteDiff Object.
class SiteDiff
  attr_reader :config, :results

  # SiteDiff installation directory.
  ROOT_DIR = File.dirname(File.dirname(__FILE__))

  # Path to misc files. Ex: *.erb, *.css.
  FILES_DIR = File.join(File.dirname(__FILE__), 'sitediff', 'files')

  # Logs a message.
  #
  # Label will be colorized and message will not.
  # Type dictates the color: can be :success, :error, or :failure.
  #
  # TODO: Only print :debug messages in debug mode.
  def self.log(message, type = :info, label = nil)
    # Prepare label.
    label ||= type unless type == :info
    label = label.to_s
    unless label.empty?
      # Colorize label.
      fg = :black
      bg = :blue

      case type
      when :info
        bg = :cyan
      when :success
        bg = :green
      when :error
        bg = :red
      when :warning
        bg = :yellow
      end

      label = '[' + label.to_s + ']'
      label = Rainbow(label)
      label = label.bg(bg) if bg
      label = label.fg(fg) if fg

      # Add a space after the label.
      label += ' '
    end

    puts label + message
  end

  ##
  # Returns the "before" site's URL.
  #
  # TODO: Remove in favor of config.before_url.
  def before
    @config.before['url']
  end

  ##
  # Returns the "after" site's URL.
  #
  # TODO: Remove in favor of config.after_url.
  def after
    @config.after['url']
  end

  # Initialize SiteDiff.
  def initialize(config, cache, verbose = true, debug = false)
    @cache = cache
    @verbose = verbose
    @debug = debug

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
    # Configure diff.
    Diff.diff_config(config)
    @config = config
  end

  # Sanitize HTML.
  def sanitize(path, read_results)
    %i[before after].map do |tag|
      html = read_results[tag].content
      # TODO: See why encoding is empty while running tests.
      #
      # The presence of an "encoding" value used to be used to determine
      # if the sanitizer would be called. However, encoding turns up blank
      # during rspec tests for some reason.
      encoding = read_results[tag].encoding
      if encoding || html.length.positive?
        section = @config.send(tag, true)
        opts = { path: path }
        opts[:output] = @config.output if @config.output
        Sanitizer.new(html, section, opts).sanitize
      else
        html
      end
    end
  end

  ##
  # Process a set of read results.
  #
  # This is the callback that processes items fetched by the Fetcher.
  def process_results(path, read_results)
    error = (read_results[:before].error || read_results[:after].error)
    if error
      diff = Result.new(path, nil, nil, nil, nil, error)
    else
      begin
        diff = Result.new(
          path,
          *sanitize(path, read_results),
          read_results[:before].encoding,
          read_results[:after].encoding,
          nil
        )
      rescue StandardError => e
        raise if @debug

        Result.new(path, nil, nil, nil, nil, "Sanitization error: #{e}")
      end
    end
    @results[path] = diff

    # Print results in order!
    while (next_diff = @results[@ordered.first])
      next_diff.log(@verbose)
      @ordered.shift
    end
  end

  ##
  # Compute diff as per config.
  #
  # @return [Integer]
  #   Number of paths which have diffs.
  def run
    # Map of path -> Result object, populated by process_results
    @results = {}
    @ordered = @config.paths.dup

    unless @cache.read_tags.empty?
      SiteDiff.log('Using sites from cache: ' + @cache.read_tags.sort.join(', '))
    end

    # TODO: Fix this after config merge refactor!
    # Not quite right. We are not passing @config.before or @config.after
    # so passing this instead but @config.after['curl_opts'] is ignored.
    curl_opts = @config.setting :curl_opts
    config_curl_opts = @config.before['curl_opts']
    curl_opts = config_curl_opts.clone.merge(curl_opts) if config_curl_opts
    fetcher = Fetch.new(
      @cache,
      @config.paths,
      @config.setting(:interval),
      @config.setting(:concurrency),
      curl_opts,
      @debug,
      before: @config.before_url,
      after: @config.after_url
    )

    # Run the Fetcher with "process results" as a callback.
    fetcher.run(&method(:process_results))

    # Order by original path order
    @results = @config.paths.map { |path| @results[path] }
    results.map { |r| r unless r.success? }.compact.length
  end

  ##
  # Get a reporter object to help with report generation.
  def report
    if @results.nil?
      raise SiteDiffException(
        'No results detected. Run SiteDiff.run before SiteDiff.report.'
      )
    end

    Report.new(@config, @cache, @results)
  end

  ##
  # Get SiteDiff gemspec.
  def self.gemspec
    file = ROOT_DIR + '/sitediff.gemspec'
    Gem::Specification.load(file)
  end

  ##
  # Ensures that a directory exists and returns a Pathname for it.
  #
  # @param [String] dir
  #   path/to/directory
  def self.ensure_dir(dir)
    dir = Pathname.new(dir) unless dir.is_a? Pathname
    dir.mkpath unless dir.directory?
    dir
  end
end

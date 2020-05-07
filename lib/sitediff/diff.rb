# frozen_string_literal: true

require 'sitediff'
require 'diffy'
require 'erb'
require 'rainbow'
require 'digest'

class SiteDiff
  # SiteDiff Diff Object.
  module Diff
    module_function

    ##
    # Generates HTML diff.
    def html_diffy(before_html, after_html)
      diff = Diffy::Diff.new(before_html, after_html)
      # If the diff is non-empty, convert it to string.
      diff.first ? diff.to_s(:html) : nil
    end

    ##
    # Generates a description about encoding.
    def encoding_blurb(encoding)
      if encoding
        "Text content returned - charset #{encoding}"
      else
        'Binary content returned'
      end
    end

    ##
    # Computes diff of binary files using MD5 hashes.
    def binary_diffy(before, after, before_encoding, after_encoding)
      if before_encoding || after_encoding
        Diffy::Diff.new(encoding_blurb(before_encoding),
                        encoding_blurb(after_encoding)).to_s(:html)
      elsif before == after
        nil
      else
        md5_before = Digest::MD5.hexdigest(before)
        md5_after = Digest::MD5.hexdigest(after)
        Diffy::Diff.new("Binary content returned md5: #{md5_before}",
                        "Binary content returned md5: #{md5_after}").to_s(:html)
      end
    end

    ##
    # Generates diff for CLI output.
    def terminal_diffy(before_html, after_html)
      args = []
      args << :color if Rainbow.enabled
      Diffy::Diff.new(before_html, after_html, context: 3)
                 .to_s(*args)
    end

    ##
    # Generates an HTML report.
    # TODO: Generate the report in SiteDif::Report instead.
    def generate_html(results, before, after, cache, relative = false)
      erb_path = File.join(SiteDiff::FILES_DIR, 'report.html.erb')
      ERB.new(File.read(erb_path)).result(binding)
    end

    ##
    # Generates diff output for a single result.
    def generate_diff_output(result)
      erb_path = File.join(SiteDiff::FILES_DIR, 'diff.html.erb')
      ERB.new(File.read(erb_path)).result(binding)
    end

    ##
    # Set configuration for Diffy.
    def diff_config(config)
      diff_options = Diffy::Diff.default_options[:diff]
      diff_options = [diff_options] unless diff_options.is_a?(Array)
      # ignore_whitespace option
      diff_options.push('-w').uniq if config.ignore_whitespace
      Diffy::Diff.default_options[:diff] = diff_options
    end
  end
end

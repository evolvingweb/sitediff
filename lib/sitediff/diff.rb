# frozen_string_literal: true

require 'sitediff'
require 'diffy'
require 'erb'
require 'rainbow'
require 'digest'

class SiteDiff
  module Diff
    module_function

    def html_diffy(before_html, after_html)
      diff = Diffy::Diff.new(before_html, after_html)
      diff.first ? # Is it non-empty?
        diff.to_s(:html) : nil
    end

    def encoding_blurb(encoding)
      if encoding
        "Text content returned - charset #{encoding}"
      else
        'Binary content returned'
      end
    end

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

    def terminal_diffy(before_html, after_html)
      args = []
      args << :color if Rainbow.enabled
      Diffy::Diff.new(before_html, after_html, context: 3)
                 .to_s(*args)
    end

    def generate_html_report(results, before, after, cache)
      erb_path = File.join(SiteDiff::FILES_DIR, 'html_report.html.erb')
      report_html = ERB.new(File.read(erb_path)).result(binding)
      report_html
    end

    def generate_diff_output(result)
      erb_path = File.join(SiteDiff::FILES_DIR, 'diff.html.erb')
      ERB.new(File.read(erb_path)).result(binding)
    end

    def css
      File.read(File.join(SiteDiff::FILES_DIR, 'sitediff.css'))
    end
  end
end

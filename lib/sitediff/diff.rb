require 'sitediff'
require 'diffy'
require 'erb'
require 'rainbow'

class SiteDiff
  module Diff
    module_function

    def html_diffy(before_html, after_html)
      diff = Diffy::Diff.new(before_html, after_html)
      diff.first ? # Is it non-empty?
        diff.to_s(:html) : nil
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

require 'diffy'
require 'erb'

module SiteDiff
  module Util
    module Diff
      module_function

      def html_diffy(before_html, after_html)
        diff = Diffy::Diff.new(before_html, after_html)
        diff.first ?  # Is it non-empty?
          diff.to_s(:html) : nil
      end

      def terminal_diffy(before_html, after_html)
        return Diffy::Diff.new(before_html, after_html, :context => 3).to_s(:color)
      end

      def generate_html_report(results, before, after)
        results.each do |result|
          result[:link] = case result[:status]
                          when "error" then result[:error]
                          when "success" then "success"
                          when "failure" then "<a href='#{result[:filename]}'>DIFF</a>"
                          end
        end
        erb_path = SiteDiff::gem_dir + '/lib/sitediff/util/html_report.html.erb'
        report_html = ERB.new(File.read(erb_path)).result(binding)
        return report_html
      end

      def generate_diff_output(result)
        erb_path = SiteDiff::gem_dir + '/lib/sitediff/util/diff.html.erb'
        return ERB.new(File.read(erb_path)).result(binding)
      end
    end
  end
end

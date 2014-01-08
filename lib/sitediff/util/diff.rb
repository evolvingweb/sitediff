require 'diff/lcs'
require 'diff/lcs/htmldiff'
require 'stringio'

module SiteDiff
  module Util
    module Diff

      def self.prepare_for_diff(str)
        str = normalize(str)
                .split($/)
                .select { |s| !s.empty? }
      end

      def self.normalize(str)
        str = remove_build_id(str)
        str = normalize_urls(str)
        str = remove_link_tags(str)
        return str
      end

      def self.remove_build_id(str)
        regex = /<input type="hidden" name="form_build_id" id="form-[a-zA-Z0-9_-]+" value="form-[a-zA-Z0-9_-]+"  \/>/
        replace = '<input type="hidden" name="form_build_id" id="FORM_BUILD_ID" value="FORM_BUILD_ID"  />'
        str.gsub!(regex, replace)
      end

      def self.remove_link_tags(str)
        str.gsub!(/<script type="text\/javascript" src="[a-zA-Z0-9.\/_?-]+"><\/script>/, '')
        str.gsub!( /<link type="text\/css" rel="stylesheet" media="[a-z]+" href="[a-zA-Z0-9.\/_?-]+" \/>/, '')
      end

      def self.normalize_urls(str)
        # remove absolute URLs mentioning the site domain
        str.gsub!(SiteDiff::Config.dev_url,'DOMAIN')
        str.gsub!(SiteDiff::Config.prod_url,'DOMAIN')

        # remove /study/2013/2014 prefix from URLs
        str.gsub!('"/study/2013-2014','"')

        # remove /study/2013-2014 prefix from jQuery.extend(Drupal.settings, {"basePath":"\/study\/2013-2014\/",
        str.gsub!('"\/study\/2013-2014\/"', '"/"')
        return str
      end

      def self.html_diff(left,right)
        left = prepare_for_diff(left)
        right = prepare_for_diff(right)

        output = StringIO.new
        options = {:expand_tabs => 0, :output => output, :title => "Diff of Prod vs Dev" }

        ::Diff::LCS::HTMLDiff.new(left, right, options).run
        return output.string
      end
    end
  end
end

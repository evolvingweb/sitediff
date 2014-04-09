require 'nokogiri'
require 'htmlentities'

module SiteDiff
  module Util
    module Sanitize
      module_function

      # Performs dom transformations.
      #
      # Currently supported transforms:
      #
      #  * { :type => "unwrap_root" }
      #  * { :type => "unwrap", :selector => "div.field-item" }
      #  * { :type => "remove", :selector => "div.extra-stuff" }
      #
      #  @arg document - Nokogiri document or Node
      #  @arg config - array of dom_transform rules
      #  @return - transformed Nokogiri document node

      def perform_dom_transforms(document, config)
        config.each do |rule|
          case rule['type']
          when "remove"
            [rule["selector"]].flatten.each do |selector|
              document.css(selector).each do |el|
                el.remove()
              end
            end
          when "unwrap_root"
            document = document.children
          when "unwrap"
            [rule["selector"]].flatten.each do |selector|
              document.css(selector).each do |el|
                el.add_next_sibling(el.children)
                el.remove()
              end
            end
          when "remove_class"
            [ rule["class"] ].flatten.each do |class_name|
              document.css(rule["selector"]).remove_class(class_name)
            end
          end
        end
        return document
      end

      def sanitize(str, config)

        if str.nil?
          return []
        end
        str = str.read

        # Nokogiri::XML chokes on HTML encoded entities like &mdash;
        # Nokogiri::HTML works, but can't do auto-indent.
        # As a work-around, we use HTMLEntities gem to decode them into utf8.
        decoder = HTMLEntities.new
        str = decoder.decode(str)
        document = Nokogiri::XML(str, &:noblanks)

        # remove double spacing, but only inside text nodes (eg not attributes)
        document.xpath('//text()').each do |node|
          node.content = node.content.gsub(/  +/, ' ')
        end

        if config["selector"]
          # TODO: handle cases where selector doesn't match
          document = document.css(config["selector"])
        end

        if config["dom_transform"]
          document = perform_dom_transforms(document, config["dom_transform"])
        end

        str = document.to_xhtml(indent: 3)

        config["sanitization"].each do |rule|
          # default type is "regex"
          str.gsub!(/#{rule['pattern']}/, rule['substitute'] || '' )
        end

        # return array of lines for diffing, removing empty (or blank) lines
        return str.split($/).select { |s| !s.match(/^\s*$/) }
      end

    end
  end
end

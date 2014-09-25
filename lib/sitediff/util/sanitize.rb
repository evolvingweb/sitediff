require 'nokogiri'

class SiteDiff
  module Util
    module Sanitize
      module_function

      # Returns a version of `node_or_ns' with element `elem' replaced by
      # its contents, without the wrapper tag. Works regardless of whether
      # `node_or_ns' is a Node or NodeSet.
      def unwrap(node_or_ns, elem)
        if node_or_ns.respond_to?(:include?) && node_or_ns.include?(elem)
          # It's a top-level node in a NodeSet, splice the children in
          idx = node_or_ns.index(elem)
          node_or_ns = node_or_ns.slice(0, idx) + elem.children +
            node_or_ns.slice(idx + 1, node_or_ns.size - idx - 1)
        else
          # We have a parent, so we can just put our children there
          elem.add_next_sibling(elem.children)
          elem.remove()
        end
        return node_or_ns
      end

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
                document = unwrap(document, el)
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

      # Pipe through our prettify script
      def prettify(str)
        stylesheet_path = File.join([File.dirname(__FILE__),'pretty_print.xsl'])
        stylesheet = Nokogiri::XSLT(File.read(stylesheet_path))
        pretty = stylesheet.apply_to(Nokogiri(str)).to_s
        return pretty
      end

      def sanitize(str, config)
        return [] if str == ''
        document = Nokogiri::HTML(str, &:noblanks)

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

        str = document.to_html
        rules = config["sanitization"] || []

        rules.each do |rule|
          # default type is "regex"
          str.gsub!(/#{rule['pattern']}/, rule['substitute'] || '' )
        end

        str = prettify(str)

        # return array of lines for diffing, removing empty (or blank) lines
        return str.split($/).select { |s| !s.match(/^\s*$/) }
      end

    end
  end
end

require 'nokogiri'
require 'set'

class SiteDiff
  module Util
    module Sanitize
      class InvalidSanitization < Exception; end

      TOOLS = {
        :array => %w[dom_transform sanitization],
        :scalar => %w[selector remove_spacing],
      }
      DOM_TRANSFORMS = Set.new(%w[remove unwrap_root unwrap remove_class])

      module_function

      # Performs dom transformations.
      #
      # Currently supported transforms:
      #
      #  * { :type => "unwrap_root" }
      #  * { :type => "unwrap", :selector => "div.field-item" }
      #  * { :type => "remove", :selector => "div.extra-stuff" }
      #
      #  @arg node - Nokogiri document or Node
      #  @arg config - array of dom_transform rules
      #  @return - transformed Nokogiri document node
      def perform_dom_transforms(node, config)
        config.each do |rule|
          case rule['type']
          when "remove"
            [rule["selector"]].flatten.each do |selector|
              node.css(selector).each do |el|
                el.remove
              end
            end
          when "unwrap_root"
            node.children.size == 1 or
              raise InvalidSanitization, "Multiple root elements in unwrap_root"
            node.children = node.children[0].children
          when "unwrap"
            [rule["selector"]].flatten.each do |selector|
              node.css(selector).each do |el|
                el.add_next_sibling(el.children)
                el.remove
              end
            end
          when "remove_class"
            [ rule["class"] ].flatten.each do |class_name|
              node.css(rule["selector"]).remove_class(class_name)
            end
          end
        end
        return node
      end

      def parse(str, force_doc = false)
        if force_doc || /<!DOCTYPE/.match(str[0, 512])
          Nokogiri::HTML(str)
        else
          Nokogiri::HTML.fragment(str)
        end
      end

      # Force this object to be a document, so we can apply a stylesheet
      def to_document(obj)
        if Nokogiri::XML::Document === obj
          return obj
        elsif Nokogiri::XML::Node === obj # or fragment
          doc = Nokogiri::HTML('<html>')
          doc.root.children = obj.children
          return doc
        else
          return to_document(parse(obj))
        end
      end

      # Pretty-print the HTML
      def prettify(obj)
        stylesheet_path = File.join([File.dirname(__FILE__),'pretty_print.xsl'])
        stylesheet = Nokogiri::XSLT(File.read(stylesheet_path))

        pretty = stylesheet.transform(to_document(obj))

        # Pull out the html element's children
        children = pretty.css('html').children
        return children.map { |c| c.to_s }.join("\n")
      end

      def remove_spacing(doc)
        # remove double spacing, but only inside text nodes (eg not attributes)
        doc.xpath('//text()').each do |node|
          node.content = node.content.gsub(/  +/, ' ')
        end
      end

      def sanitize(str, config)
        return [] if str == ''
        node = parse(str)

        remove_spacing(node) if config['remove_spacing']

        if config["selector"]
          # TODO: handle cases where selector doesn't match
          node.children = node.css(config["selector"])
        end

        if config["dom_transform"]
          node = perform_dom_transforms(node, config["dom_transform"])
        end

        str = node.to_html
        rules = config["sanitization"] || []

        rules.each do |rule|
          # default type is "regex"
          str.gsub!(/#{rule['pattern']}/, rule['substitute'] || '' )
        end

        str = prettify(str)

        # return array of lines for diffing, removing empty (or blank) lines
        # $/ is the input record separator
        return str.split($/).select { |s| !s.match(/^\s*$/) }.join($/)
      end

    end
  end
end

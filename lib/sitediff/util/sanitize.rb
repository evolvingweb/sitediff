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
          type = rule['type'] or
            raise InvalidSanitization, "DOM transform needs a type"
          DOM_TRANSFORMS.include?(type) or
            raise InvalidSanitization, "No DOM transform named #{type}"

          meth = 'transform_' + type

          if sels = rule['selector']
            sels = [sels].flatten # Either array or scalar is fine
            # Call method for each node the selectors find
            sels.each do |sel|
              node.css(sel).each { |e| send(meth, rule, e) }
            end
          else
            send(meth, rule, node)
          end
        end
      end

      def transform_remove(rule, el)
        el.remove
      end
      def transform_unwrap(rule, el)
        el.add_next_sibling(el.children)
        el.remove
      end
      def transform_remove_class(rule, el)
        # Must call remove_class on a NodeSet!
        ns = Nokogiri::XML::NodeSet.new(el.document, [el])
        [rule['class']].flatten.each do |class_name|
          ns.remove_class(class_name)
        end
      end
      def transform_unwrap_root(rule, node)
        node.children.size == 1 or
          raise InvalidSanitization, "Multiple root elements in unwrap_root"
        node.children = node.children[0].children
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
        str = children.map { |c| c.to_s }.join("\n")

        # Remove blank lines. $/ is the input record separator
        return str.split($/).reject { |s| s.match(/^\s*$/) }.join($/)
      end

      def remove_spacing(doc)
        # remove double spacing, but only inside text nodes (eg not attributes)
        doc.xpath('//text()').each do |node|
          node.content = node.content.gsub(/  +/, ' ')
        end
      end

      # Do one regexp transformation on a string
      def substitute(str, rule)
        str.gsub!(/#{rule['pattern']}/, rule['substitute'] || '' )
        str
      end

      # Do all regexp sanitization rules
      def perform_regexps(node, rules)
        rules ||= []

        # First do rules with a selector
        rules.each do |rule|
          if sel = rule['selector']
            node.css(sel).each do |e|
              e.replace(substitute(e.to_html, rule))
            end
          end
        end

        # If needed, do rules without a selector. We'd rather not convert to
        # a string unless necessary.
        global_rules = rules.reject { |r| r['selector'] }
        return node if global_rules.empty?

        str = node.to_html # Convert to string
        global_rules.each { |r| substitute(str, r) }
        return str
      end

      def sanitize(str, config)
        return '' if str == ''

        node = parse(str)

        remove_spacing(node) if config['remove_spacing']

        if sel = config["selector"]
          node.children = node.css(sel)
        end

        if transform = config["dom_transform"]
          perform_dom_transforms(node, transform)
        end

        obj = perform_regexps(node, config['sanitization'])

        return prettify(obj)
      end
    end
  end
end

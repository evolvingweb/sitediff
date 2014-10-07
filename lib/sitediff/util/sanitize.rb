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
      #  @arg rules - array of dom_transform rules
      #  @return - transformed Nokogiri document node
      def perform_dom_transforms(node, rules)
        rules.each do |rule|
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

      def parse(str, force_doc = false, log_errors = false)
        if force_doc || /<!DOCTYPE/.match(str[0, 512])
          doc = Nokogiri::HTML(str)
          doc
        else
          doc = Nokogiri::HTML.fragment(str)
        end
        if log_errors
          doc.errors.each do |e|
            SiteDiff::log "Error in parsing HTML document: #{e}", :yellow, :black
          end
        end
        doc
      end

      # Force this object to be a document, so we can apply a stylesheet
      def to_document(obj)
        if Nokogiri::XML::Document === obj
          return obj
        elsif Nokogiri::XML::Node === obj # or fragment
          return parse(obj.to_s, true)

          # This ought to work, and would be faster,
          # but seems to segfault Nokogiri
          # doc = Nokogiri::HTML('<html><body>')
          # doc.at('body').children = obj.children
          # return doc
        else
          return to_document(parse(obj))
        end
      end

      # Pretty-print the HTML
      def prettify(obj)
        @stylesheet ||= begin
          stylesheet_path = File.join([File.dirname(__FILE__),'pretty_print.xsl'])
          Nokogiri::XSLT(File.read(stylesheet_path))
        end

        # Pull out the html element's children
        # The obvious way to do this is to iterate over pretty.css('html'),
        # but that tends to segfault Nokogiri
        str = @stylesheet.apply_to(to_document(obj))

        # Remove xml declaration and <html> tags
        str.sub!(/\A<\?xml.*$\n/, '')
        str.sub!(/\A^<html>$\n/, '')
        str.sub!(%r[</html>\n\Z], '')

        # Remove top-level indentation
        indent = /\A(\s*)/.match(str)[1].size
        str.gsub!(/^\s{,#{indent}}/, '')

        # Remove blank lines
        str.gsub!(/^\s*$\n/, '')

        return str
      end

      def remove_spacing(doc)
        # remove double spacing, but only inside text nodes (eg not attributes)
        doc.xpath('//text()').each do |node|
          node.content = node.content.gsub(/  +/, ' ')
        end
      end

      # Do one regexp transformation on a string
      def substitute(str, rule)
        #FIXME escape forward slashes, right now we are escaping them in YAML!
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

      def select_root(node, sel)
        return node unless sel

        # When we choose a new root, we always become a DocumentFragment,
        # and lose any DOCTYPE and such.
        ns = node.css(sel)
        unless node.fragment?
          node = Nokogiri::HTML.fragment('')
        end
        node.children = ns
        return node
      end

      def sanitize(str, config)
        return '' if str == ''

        node = parse(str)

        remove_spacing(node) if config['remove_spacing']
        node = select_root(node, config['selector'])
        if transform = config['dom_transform']
          perform_dom_transforms(node, transform)
        end

        obj = perform_regexps(node, config['sanitization'])

        return prettify(obj)
      end
    end
  end
end

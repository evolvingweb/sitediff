require 'sitediff'
require 'sitediff/exception'
require 'sitediff/sanitize/dom_transform'
require 'sitediff/sanitize/regexp'
require 'nokogiri'
require 'set'

class SiteDiff
  class Sanitizer
    class InvalidSanitization < SiteDiffException; end

    TOOLS = {
      array: %w[dom_transform sanitization],
      scalar: %w[selector remove_spacing]
    }.freeze
    DOM_TRANSFORMS = Set.new(%w[remove unwrap_root unwrap remove_class])

    def initialize(html, config, opts = {})
      @html = html
      @config = config
      @opts = opts
    end

    def sanitize
      return '' if @html == '' # Quick return on empty input

      @node = Sanitizer.domify(@html)
      @html = nil

      remove_spacing
      selector
      dom_transforms
      regexps

      @html || Sanitizer.prettify(@node)
    end

    # Return whether or not we want to keep a rule
    def want_rule(rule)
      return false unless rule
      return false if rule['disabled']

      # Filter out if path regexp doesn't match
      if (pathre = rule['path']) && (path = @opts[:path])
        return ::Regexp.new(pathre).match(path)
      end

      true
    end

    # Canonicalize a simple rule, eg: 'remove_spacing' or 'selector'.
    # It may be a simple value, or a hash, or an array of hashes.
    # Turn it into an array of hashes.
    def canonicalize_rule(name)
      (rules = @config[name]) || (return nil)

      if rules[0] && rules[0].respond_to?(:[]) && rules[0]['value']
        # Already an array
      elsif rules['value']
        # Hash, put it in an array
        rules = [rules]
      else
        # Scalar, put it in a hash
        rules = [{ 'value' => rules }]
      end

      want = rules.select { |r| want_rule(r) }
      return nil if want.empty?
      raise "Too many matching rules of type #{name}" if want.size > 1
      want.first
    end

    # Perform 'remove_spacing' action
    def remove_spacing
      (rule = canonicalize_rule('remove_spacing')) || return
      Sanitizer.remove_node_spacing(@node) if rule['value']
    end

    # Perform 'selector' action, to choose a new root
    def selector
      (rule = canonicalize_rule('selector')) || return
      @node = Sanitizer.select_fragments(@node, rule['value'])
    end

    # Applies regexps. Also
    def regexps
      (rules = @config['sanitization']) || return
      rules = rules.select { |r| want_rule(r) }

      rules.map! { |r| Regexp.create(r) }
      selector, global = rules.partition(&:selector?)

      selector.each { |r| r.apply(@node) }
      @html = Sanitizer.prettify(@node)
      @node = nil
      global.each { |r| r.apply(@html) }
    end

    # Perform DOM transforms
    def dom_transforms
      (rules = @config['dom_transform']) || return
      rules = rules.select { |r| want_rule(r) }

      rules.each do |rule|
        transform = DomTransform.create(rule)
        transform.apply(@node)
      end
    end

    ##### Implementations of actions #####

    # Remove double-spacing inside text nodes
    def self.remove_node_spacing(node)
      # remove double spacing, but only inside text nodes (eg not attributes)
      node.xpath('//text()').each do |el|
        el.content = el.content.gsub(/  +/, ' ')
      end
    end

    # Get a fragment consisting of the elements matching the selector(s)
    def self.select_fragments(node, sel)
      # When we choose a new root, we always become a DocumentFragment,
      # and lose any DOCTYPE and such.
      ns = node.css(sel)
      node = Nokogiri::HTML.fragment('') unless node.fragment?
      node.children = ns
      node
    end

    # Pretty-print some HTML
    def self.prettify(obj)
      @stylesheet ||= begin
        stylesheet_path = File.join(SiteDiff::FILES_DIR, 'pretty_print.xsl')
        Nokogiri::XSLT(File.read(stylesheet_path))
      end

      # Pull out the html element's children
      # The obvious way to do this is to iterate over pretty.css('html'),
      # but that tends to segfault Nokogiri
      str = @stylesheet.apply_to(to_document(obj))

      # There's a lot of cruft left over,that we don't want

      # Remove xml declaration and <html> tags
      str.sub!(/\A<\?xml.*$\n/, '')
      str.sub!(/\A^<html>$\n/, '')
      str.sub!(%r{</html>\n\Z}, '')

      # Remove top-level indentation
      indent = /\A(\s*)/.match(str)[1].size
      str.gsub!(/^\s{,#{indent}}/, '')

      # Remove blank lines
      str.gsub!(/^\s*$\n/, '')

      str
    end

    # Parse HTML into a node
    def self.domify(str, force_doc = false)
      if force_doc || /<!DOCTYPE/.match(str[0, 512])
        Nokogiri::HTML(str)
      else
        Nokogiri::HTML.fragment(str)
      end
    end

    # Force this object to be a document, so we can apply a stylesheet
    def self.to_document(obj)
      if Nokogiri::XML::Document == obj
        obj
      elsif Nokogiri::XML::Node == obj # node or fragment
        domify(obj.to_s, true)
      else
        to_document(domify(obj))
      end
    end
  end
end

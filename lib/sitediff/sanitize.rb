require 'sitediff/exception'
require 'sitediff/sanitize/dom_transform'
require 'sitediff/sanitize/regexp'
require 'nokogiri'
require 'set'

class SiteDiff
module Sanitize
  def self.sanitize(str, config)
    Sanitizer.new(str, config).sanitize
  end
end

class Sanitizer
class InvalidSanitization < SiteDiffException; end

TOOLS = {
  :array => %w[dom_transform sanitization],
  :scalar => %w[selector remove_spacing],
}
DOM_TRANSFORMS = Set.new(%w[remove unwrap_root unwrap remove_class])

def initialize(html, config, opts = {})
  @html = html
  @config = config
  @opts = opts
end

def sanitize
  return '' if @html == '' # Quick return on empty input

  @node, @html = Sanitizer.domify(@html), nil

  remove_spacing
  selector
  dom_transforms
  regexps

  return @html || Sanitizer.prettify(@node)
end

# Applies regexps. Also
def regexps
  rules = @config['sanitization'] or return
  rules.reject! { |r| r['disabled'] }

  rules.map! { |r| Regexp.create(r) }
  selector, global = rules.partition { |r| r.selector? }

  selector.each { |r| r.apply(@node) }
  @html, @node = Sanitizer.prettify(@node), nil
  global.each { |r| r.apply(@html) }
end

# Perform 'remove_spacing' action
def remove_spacing
  return unless @config['remove_spacing']
  Sanitizer.remove_node_spacing(@node)
end

# Perform 'selector' action, to choose a new root
def selector
  sel = @config['selector'] or return
  @node = Sanitizer.select_fragments(@node, sel)
end

# Perform DOM transforms
def dom_transforms
  rules = @config['dom_transform'] or return
  rules.reject! { |r| r['disabled'] }
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
  unless node.fragment?
    node = Nokogiri::HTML.fragment('')
  end
  node.children = ns
  return node
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
  str.sub!(%r[</html>\n\Z], '')

  # Remove top-level indentation
  indent = /\A(\s*)/.match(str)[1].size
  str.gsub!(/^\s{,#{indent}}/, '')

  # Remove blank lines
  str.gsub!(/^\s*$\n/, '')

  return str
end

# Parse HTML into a node
def self.domify(str, force_doc = false)
  if force_doc || /<!DOCTYPE/.match(str[0, 512])
    return Nokogiri::HTML(str)
  else
    return Nokogiri::HTML.fragment(str)
  end
end

# Force this object to be a document, so we can apply a stylesheet
def self.to_document(obj)
  if Nokogiri::XML::Document === obj
    return obj
  elsif Nokogiri::XML::Node === obj # node or fragment
    return domify(obj.to_s, true)

    # This ought to work, and would be faster,
    # but seems to segfault Nokogiri
    if false
      doc = Nokogiri::HTML('<html><body>')
      doc.at('body').children = obj.children
      return doc
    end
  else
    return to_document(domify(obj))
  end
end

end
end

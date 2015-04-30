require 'sitediff/exception'
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

# Check if a regexp applies
def regexp_applies(str, rule)
  dup = str.dup
  substitute(str, rule)
  dup != str
end

# Do one regexp transformation on a string
def substitute(str, rule)
  #FIXME escape forward slashes, right now we are escaping them in YAML!
  str.gsub!(/#{rule['pattern']}/, rule['substitute'] || '' )
  str
end

# Find the context for a regexp rule. Pass on the context to a handler
# block
def context_for_regexp(node, text, rule, &block)
  if sel = rule['selector']
    node.css(sel).each do |e|
      block[e, e.to_html]
    end
  else
    block[nil, text]
  end
end

# Do all regexp sanitization rules
def perform_regexps(node, rules)
  rules ||= []
  rules.reject! { |r| r['disabled'] }

  # First do rules with a selector
  rules.each do |rule|
    next unless rule['selector']
    context_for_regexp(node, nil, rule) do |elem, text|
      elem.replace(substitute(text, rule))
    end
  end

  # If needed, do rules without a selector. We'd rather not convert to
  # a string unless necessary.
  global_rules = rules.reject { |r| r['selector'] }
  str = Sanitizer.prettify(node)
  global_rules.each do |r|
    context_for_regexp(nil, str, r) { |elem, text| substitute(text, r) }
  end
  return str
end


def sanitize
  return '' if @html == '' # Quick return on empty input

  @node = Sanitizer.domify(@html)

  remove_spacing
  selector
  dom_transforms

  # This does prettify
  html = perform_regexps(@node, @config['sanitization'])
  return html
end


def remove_spacing
  return unless @config['remove_spacing']
  Sanitizer.node_remove_spacing(@node)
end

def selector
  sel = @config['selector'] or return
  @node = Sanitizer.node_selector(@node, sel)
end

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
def dom_transforms
  rules = @config['dom_transform'] or return
  rules.each { |rule| dom_transform(rule) }
end

def dom_transform(rule)
  return if rule['disabled']

  type = rule['type'] or
    raise InvalidSanitization, "DOM transform needs a type"
  DOM_TRANSFORMS.include?(type) or
    raise InvalidSanitization, "No DOM transform named #{type}"


  meth = 'transform_' + type

  if sels = rule['selector']
    sels = [sels].flatten # Either array or scalar is fine
    # Call method for each node the selectors find
    sels.each do |sel|
      @node.css(sel).each { |e| send(meth, rule, e) }
    end
  else
    send(meth, rule, @node)
  end
end

def self.node_remove_spacing(node)
  # remove double spacing, but only inside text nodes (eg not attributes)
  node.xpath('//text()').each do |el|
    el.content = el.content.gsub(/  +/, ' ')
  end
end

def self.node_selector(node, sel)
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
  elsif Nokogiri::XML::Node === obj # or fragment
    return domify(obj.to_s, true)

    # This ought to work, and would be faster,
    # but seems to segfault Nokogiri
    # doc = Nokogiri::HTML('<html><body>')
    # doc.at('body').children = obj.children
    # return doc
  else
    return to_document(domify(obj))
  end
end

end
end

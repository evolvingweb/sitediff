require 'sitediff/sanitize'
require 'set'
require 'pathname'
require 'nokogiri'

class SiteDiff
# Find appropriate rules for a given site
class Rules
  def initialize(config, disabled = false)
    @disabled = disabled
    @config = config
    find_sanitization_candidates
    @rules = Hash.new { |h, k| h[k] = Set.new }
  end

  def find_sanitization_candidates
    @candidates = Set.new

    rules_dir = Pathname.new(__FILE__).dirname + 'files' + 'rules'
    rules_dir.children.each do |f|
      next unless f.file? && f.extname == '.yaml'
      conf = YAML.load_file(f)
      @candidates.merge(conf['sanitization'])
    end
  end

  def handle_page(tag, html, doc)
    found = find_rules(html, doc)
    @rules[tag].merge(found)
  end

  # Yield a set of rules that seem reasonable for this HTML
  # assumption: the YAML file is a list of regexp rules only
  def find_rules(html, doc)
    rules = []

    @candidates.each do |rule|
      SiteDiff::Sanitize::context_for_regexp(doc, html, rule) do |elem, text|
        if SiteDiff::Sanitize::regexp_applies(text, rule)
          rules << rule
        end
      end
    end
    return rules
  end

  # Find all rules from all rulesets that apply for all pages
  def add_config
    r1, r2 = *@rules.values_at(:before, :after)
    add_section('before', r1 - r2)
    add_section('after', r2 - r1)
    add_section(nil, r1 & r2)
  end

  def add_section(name, rules)
    return if rules.empty?
    conf = name ? @config[name] : @config
    if @disabled
      rules.each { |r| r['disabled'] = true }
    end
    conf['sanitization'] = rules.to_a.sort_by { |r| r['title'] }
  end
end
end

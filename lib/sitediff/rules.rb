require 'sitediff/sanitize'
require 'set'
require 'pathname'
require 'nokogiri'

class SiteDiff
# Find appropriate rules for a given site
class Rules
  # FIXME each Rules object knows what the before and after root URLs are, and it has
  # a list of sanitization rule candidates, loaded from a YAML file found in
  # SITEDIFF_LIB/files/rules/
  def initialize(sanitization_candidates)
    @sanitization_candidates = sanitization_candidates
  end

  # Yield a set of rules that seem reasonable for this HTML
  # assumption: the YAML file is a list of regexp rules only
  def find_rules(html, doc)
    return {} unless html
    rules = []

    @sanitization_candidates.each do |rule|
      SiteDiff::Sanitize::context_for_regexp(doc, html, rule) do |elem, text|
        if SiteDiff::Sanitize::regexp_applies(text, rule)
          rules << { 'sanitization' => rule }
        end
      end
    end
    return rules
  end

  # Create Rules objects from YAML files found in SITEDIFF_LIB/files/rules/
  def self.rulesets
    rules = []
    rules_dir = Pathname.new(__FILE__).dirname + 'files' + 'rules'
    rules_dir.children.each do |f|
      next unless f.file? && f.extname == '.yaml'
      rules << Rules.new(YAML.load_file(f))
    end
    rules
  end

  # Find all rules from all rulesets that apply for all pages
  def self.rules_config(html_by_uri_by_pos)
    types = SiteDiff::Sanitize::TOOLS.values.flatten(1)
    rules = { 'before' => Set.new, 'after' => Set.new }
    rulesets = self.rulesets

    html_by_uri_by_pos.each do |pos, html_by_uri|
      html_by_uri.each do |uri, html|
        doc = html ? Nokogiri::HTML(html) : nil
        rulesets.each do |rs|
          rules[pos].merge(rs.find_rules(html, doc))
        end
      end
    end

    # rules[before] - rules[after]  goes into before:
    # rules[after]  - rules[before] goes into after:
    config = {'before' => {}, 'after' => {}}
    %w(before  after).each do |pos|
      other = (pos == 'after') ? 'before' : 'after'
      (rules[pos] - rules[other]).each do |rule|
        # Coalesce by type
        k = rule.keys.first
        config[pos][k] ||= []
        config[pos][k] << rule[k]
      end
    end

    # rules[before] & rules[after] becomes global config
    (rules['before'] & rules['after']).each do |rule|
      # Coalesce by type
      k = rule.keys.first
      config[k] ||= []
      config[k] << rule[k]
    end
    puts YAML.dump config

    return config
  end
end
end

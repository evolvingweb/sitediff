require 'sitediff/sanitize'
require 'set'
require 'pathname'
require 'nokogiri'

class SiteDiff
# Find appropriate rules for a given site
class Rules
  # each Rules object knows what the before and after root URLs are, and it has
  # a list of sanitization rule candidates, loaded from a YAML file found in
  # SITEDIFF_LIB/files/rules/
  def initialize(roots, sanitization_candidates)
    @roots = roots
    @sanitization_candidates = sanitization_candidates
  end

  # Yield a set of rules that seem reasonable for this HTML
  def find_rules(uri, html, doc)
    rules = []

    if html
      @sanitization_candidates.each do |rule|
        SiteDiff::Sanitize::context_for_regexp(doc, html, rule) do |elem, text|
          if SiteDiff::Sanitize::regexp_applies(text, rule)
            rules << { 'sanitization' => rule }
          end
        end
      end
    end

    return rules
  end

  # Create Rules objects from YAML files found in SITEDIFF_LIB/files/rules/
  def self.rulesets(roots)
    rules = []
    rules_dir = Pathname.new(__FILE__).dirname + 'files' + 'rules'
    rules_dir.children.each do |f|
      next unless f.file? && f.extname == '.yaml'
      rules << Rules.new(roots, YAML.load_file(f))
    end
    rules
  end

  # Find all rules from all modules for all pages
  def self.find_rules(roots, found)
    rules = Set.new
    rulesets = self.rulesets(roots)

    found.each do |uri, html|
      doc = html ? Nokogiri::HTML(html) : nil
      rulesets.each do |rs|
        rules.merge(rs.find_rules(uri, html, doc))
      end
    end

    # Coalesce by type
    config = {}
    rules.each do |rule|
      k = rule.keys.first
      config[k] ||= []
      config[k] << rule[k]
    end

    return config
  end
end
end

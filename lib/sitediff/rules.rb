require 'sitediff/sanitize'
require 'set'
require 'pathname'
require 'nokogiri'

class SiteDiff
# Find appropriate rules for a given site
class Rules
  # A bunch of sanitization rules that we might want
  def sanitization_candidates; []; end

  # Yield a set of rules that seem reasonable for this HTML
  def find_rules(uri, html, doc)
    rules = []

    if html
      sanitization_candidates.each do |rule|
        SiteDiff::Sanitize::context_for_regexp(doc, html, rule) do |elem, text|
          if SiteDiff::Sanitize::regexp_applies(text, rule)
            rules << { 'sanitization' => rule }
          end
        end
      end
    end

    return rules
  end

  # Find modules that define rules
  def self.rulesets
    dir = Pathname.new(__FILE__).sub_ext('')
    dir.each_child do |child|
      next unless child.file? && child.extname == '.rb'
      load child
    end

    @rulesets.map { |c| c.new }
  end

  def self.inherited(subc)
    (@rulesets ||= []) << subc
  end

  # Find all rules from all modules for all pages
  def self.find_rules(uris)
    rules = Set.new
    rulesets = self.rulesets

    uris.each do |uri, html|
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

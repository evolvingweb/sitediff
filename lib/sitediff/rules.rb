# frozen_string_literal: true

require 'sitediff/sanitize/regexp'
require 'pathname'
require 'set'

class SiteDiff
  # Find appropriate rules for a given site
  class Rules
    def initialize(config, disabled = false)
      @disabled = disabled
      @config = config
      find_sanitization_candidates
      @rules = Hash.new { |h, k| h[k] = Set.new }
    end

    attr_reader :disabled

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
      @candidates.select do |rule|
        re = SiteDiff::Sanitizer::Regexp.create(rule)
        re.applies?(html, doc)
      end
    end

    # Find all rules from all rulesets that apply for all pages
    def add_config
      have_both = @rules.include?(:before)

      r1, r2 = *@rules.values_at(:before, :after)
      if have_both
        add_section('before', r1 - r2)
        add_section('after', r2 - r1)
        add_section(nil, r1 & r2)
      else
        add_section(nil, r2)
      end
    end

    def add_section(name, rules)
      return if rules.empty?

      conf = name ? @config[name] : @config
      rules.each { |r| r['disabled'] = true } if @disabled
      conf['sanitization'] = rules.to_a.sort_by { |r| r['title'] }
    end
  end
end

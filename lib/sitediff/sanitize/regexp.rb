# frozen_string_literal: true

class SiteDiff
  class Sanitizer
    # Regular Expression Object.
    class Regexp
      ##
      # Creates a RegExp object.
      def initialize(rule)
        @rule = rule
      end

      ##
      # Whether the RegExp has a selector.
      def selector?
        false
      end

      ##
      # Whether the RegExp applies to the given markup.
      def applies?(html, _node)
        applies_to_string?(html)
      end

      ##
      # Applies the RegExp to the markup.
      def apply(html)
        gsub!(html)
      end

      ##
      # Creates a RegExp object as per rule.
      def self.create(rule)
        rule['selector'] ? WithSelector.new(rule) : new(rule)
      end

      ##
      # A RegExp with selector.
      class WithSelector < Regexp
        ##
        # Whether the RegExp has a selector.
        def selector?
          true
        end

        ##
        # TODO: Document what this method does.
        def contexts(node)
          selectors = @rule['selector']
          node.css(selectors).each { |e| yield(e) }
        end

        ##
        # Whether the RegExp applies to the given markup.
        def applies?(_html, node)
          enum_for(:contexts, node).any? { |e| applies_to_string?(e.to_html) }
        end

        ##
        # Applies the RegExp to the markup.
        def apply(node)
          contexts(node) { |e| e.replace(gsub!(e.to_html)) }
        end
      end

      protected

      def gsub!(str)
        re = ::Regexp.new(@rule['pattern'])
        sub = @rule['substitute'] || ''
        # Expecting a mutation here. Do not reassign the variable str
        # for the purpose of removing UTF-8 encoding errors.
        str.gsub!(re, sub)
        str
      end

      def applies_to_string?(str)
        gsub!(str.dup) != str
      end
    end
  end
end

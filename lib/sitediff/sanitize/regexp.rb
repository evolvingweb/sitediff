# frozen_string_literal: true

class SiteDiff
  class Sanitizer
    # Regular Expression Object.
    class Regexp
      def initialize(rule)
        @rule = rule
      end

      def selector?
        false
      end

      def applies?(html, _node)
        applies_to_string?(html)
      end

      def apply(html)
        gsub!(html)
      end

      def self.create(rule)
        rule['selector'] ? WithSelector.new(rule) : new(rule)
      end

      # RegExp with selector.
      class WithSelector < Regexp
        def selector?
          true
        end

        def contexts(node)
          sels = @rule['selector']
          node.css(sels).each { |e| yield(e) }
        end

        def applies?(_html, node)
          enum_for(:contexts, node).any? { |e| applies_to_string?(e.to_html) }
        end

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

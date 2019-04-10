# frozen_string_literal: true

require 'sitediff/sanitize'
require 'nokogiri'

class SiteDiff
  class Sanitizer
    # Currently supported transforms:
    #
    #  * { :type => "unwrap_root" }
    #  * { :type => "unwrap", :selector => "div.field-item" }
    #  * { :type => "remove", :selector => "div.extra-stuff" }
    #  * { :type => "remove_class", :class => 'class1' }
    class DomTransform
      # Supported dom_transform types.
      TRANSFORMS = {}

      def initialize(rule)
        @rule = rule
      end

      # Often an array or scalar are both ok values. Turn either into an array.
      def to_array(val)
        [val].flatten
      end

      def targets(node)
        selectors = to_array(@rule['selector'])
        selectors.each do |sel|
          node.css(sel).each { |n| yield n }
        end
      end

      def apply(node)
        targets(node) { |t| process(t) }
      end

      def self.register(name)
        TRANSFORMS[name] = self
      end

      def self.create(rule)
        (type = rule['type']) ||
          raise(InvalidSanitization, 'DOM transform needs a type')
        (transform = TRANSFORMS[type]) ||
          raise(InvalidSanitization, "No DOM transform named #{type}")
        transform.new(rule)
      end

      # Remove elements matching 'selector'
      class Remove < DomTransform
        register 'remove'
        def process(node)
          node.remove
        end
      end

      # Unwrap elements matching 'selector'
      class Unwrap < DomTransform
        register 'unwrap'
        def process(node)
          node.add_next_sibling(node.children)
          node.remove
        end
      end

      # Remove classes from elements matching selector
      class RemoveClass < DomTransform
        register 'remove_class'
        def process(node)
          classes = to_array(@rule['class'])

          # Must call remove_class on a NodeSet!
          ns = Nokogiri::XML::NodeSet.new(node.document, [node])
          classes.each do |class_name|
            ns.remove_class(class_name)
          end
        end
      end

      # Unwrap the root element
      class UnwrapRoot < DomTransform
        register 'unwrap_root'
        def apply(node)
          (node.children.size == 1) ||
            raise(InvalidSanitization, 'Multiple root elements in unwrap_root')
          node.children = node.children[0].children
        end
      end
    end
  end
end

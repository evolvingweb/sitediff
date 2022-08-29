# frozen_string_literal: true

require 'pathname'
require 'sitediff/config'

class SiteDiff
  class Config
    ##
    # Preset helper.
    class Preset
      ##
      # Directory in which presets live.
      #
      # TODO: Move this outside "lib".
      DIRECTORY = "#{Pathname.new(__dir__).dirname}/presets".freeze

      ##
      # Reads preset rules.
      #
      # @param [String] preset
      #   Presets
      #
      # @return [Hash]
      #   A hash containing the preset's rules.
      def self.read(name)
        @cache = {} if @cache.nil?

        # Load and cache preset config.
        if @cache[name].nil?
          exist? name, exception: true
          @cache[name] = Config.load_conf file(name)
        end

        @cache[name]
      end

      ##
      # Get all possible rules.
      #
      # @return [Array]
      #   All presets.
      def self.all
        # Load and cache preset names.
        if @all.nil?
          @all = []
          pattern = "#{DIRECTORY}/*.yaml"
          Dir.glob(pattern) do |file|
            @all << File.basename(file, '.yaml')
          end
        end

        @all
      end

      ##
      # Checks whether a preset exists.
      def self.exist?(name, exception: false)
        result = File.exist?(file(name))

        # Raise an exception, if required.
        if exception && !result
          raise Config::InvalidConfig, "Preset not found: #{name}"
        end

        result
      end

      ##
      # Returns the path to a preset file.
      def self.file(name)
        DIRECTORY + "/#{name}.yaml"
      end
    end
  end
end

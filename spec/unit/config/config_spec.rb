# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'

describe SiteDiff::Config do
  describe '::all' do
    it 'Reads a config file' do
      config = SiteDiff::Config.new(
        'spec/unit/config/config.yaml',
        Dir.mktmpdir
      )

      # Config hash including defaults.
      hash = config.all
      settings = hash['settings']

      # Certain data must be of type Hash.
      expect(hash).to be_kind_of Hash
      expect(settings).to be_kind_of Hash
      expect(settings['curl_opts']).to be_kind_of Hash

      # Must contain certain keys.
      %w[
        before
        after
        settings
        selector
        sanitization
        dom_transform
      ].each do |key|
        expect(hash).to include key
      end

      # Sanitization rules must be preserved.
      expect(hash['sanitization']).to be_kind_of Array
      expect(hash['before']['sanitization']).to be_kind_of Array
      expect(hash['after']['sanitization']).to be_kind_of Array

      # Setting override must be preserved.
      expect(settings['depth']).to eq 2
      expect(settings['curl_opts']['connecttimeout']).to eq 10

      # Undefined items should not be present in filtered config.
      expect(settings.keys).to_not include 'interval'

      # Default values should not be present in filtered config.
      expect(settings.keys).not_to include 'concurrency'
    end
  end

  describe '::setting' do
    it 'Reads settings from config' do
      config = SiteDiff::Config.new(
        'spec/unit/config/config.yaml',
        Dir.mktmpdir
      )

      # Read all settings.
      expect(config.settings).to be_kind_of Hash
      expect(config.settings.keys).to include 'interval'
      expect(config.setting(:interval)).to equal 0
      expect(config.setting(:depth)).to equal 2
      expect(config.setting(:curl_opts)).to be_kind_of Hash
    end
  end
end

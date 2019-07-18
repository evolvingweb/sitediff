# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'

describe SiteDiff::Config do
  describe '::section' do
    it 'Reads before/after sections' do
      config = SiteDiff::Config.new(
        'spec/unit/config/config.yaml',
        Dir.mktmpdir
      )

      # Sections should be accessible via methods.
      expect(config.before).to be_kind_of Hash
      expect(config.after).to be_kind_of Hash

      # Sanitization rules must be preserved.
      expect(config.before.keys).to include 'sanitization'
      expect(config.before['sanitization']).to be_kind_of Array
      expect(config.after.keys).to include 'sanitization'
      expect(config.after['sanitization']).to be_kind_of Array

      # Section URLs must be readable.
      expect(config.before_url).to eq 'spec/fixtures/ruby-doc.org/core-1.9.3'
      expect(config.after_url).to eq 'spec/fixtures/ruby-doc.org/core-2.0'
    end
  end

  describe '::setting' do
    it 'Reads settings from a config file' do
      config = SiteDiff::Config.new(
        'spec/unit/config/config.yaml',
        Dir.mktmpdir
      )

      # Depth is set, so we should get that value.
      expect(config.setting(:depth)).to eq 2

      # Interval is not set, so we should get the default.
      expect(config.setting(:interval)).to eq SiteDiff::Config::DEFAULT_CONFIG['settings']['interval']
    end
  end

  describe '::all' do
    it 'Reads config file contents as a hash' do
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

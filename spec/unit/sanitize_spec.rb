# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'

describe SiteDiff::Sanitizer do
  describe '::remove_spacing' do
    it 'normalizes space but only within text nodes' do
      doc = Nokogiri::HTML('<html><body  class="x  y">  z  </body></html>')
      SiteDiff::Sanitizer.remove_node_spacing(doc)
      expect(doc.to_s).to include '<html><body class="x  y"> z </body></html>'
    end
  end

  describe '::sanitize' do
    %w[DOCTYPE doctype DoCtYpE].each do |doctype|
      context "with a #{doctype} declaration" do
        it 'preserves html and body attributes' do
          input = "<!#{doctype} html><html lang=\"en\"><body class=\"before\"><p>Same</p></body></html>"
          output = SiteDiff::Sanitizer.new(input, {}).sanitize
          expect(output).to include('<html lang="en">', '<body class="before">')

          changed = input.sub('lang="en"', 'lang="fr"')
          expect(SiteDiff::Sanitizer.new(changed, {}).sanitize).not_to eq(output)
          changed = input.sub('class="before"', 'class="after"')
          expect(SiteDiff::Sanitizer.new(changed, {}).sanitize).not_to eq(output)
          expect(SiteDiff::Sanitizer.new(input, {}).sanitize).to eq(output)
        end
      end
    end

    [{}, { 'sanitization' => [{ 'pattern' => 'unchanged' }] }].each do |config|
      context "with configuration #{config.inspect}" do
        it 'preserves UTF-8 text and distinguishes non-ASCII changes' do
          input = '<p>Röder — 東京</p>'
          output = SiteDiff::Sanitizer.new(input, config).sanitize
          expect(output).to include('Röder — 東京')
          expect(output.encoding).to eq(Encoding::UTF_8)
          expect(output.valid_encoding?).to be(true)
          expect(SiteDiff::Sanitizer.new('<p>Räder — 東京</p>', config).sanitize).not_to eq(output)
          expect(SiteDiff::Sanitizer.new(input, config).sanitize).to eq(output)
        end

        it 'converts text with a non-UTF-8 source encoding' do
          input = '<p>Röder</p>'.encode(Encoding::ISO_8859_1)
          output = SiteDiff::Sanitizer.new(input, config).sanitize
          expect(output).to include('Röder')
          expect(output.encoding).to eq(Encoding::UTF_8)
          expect(output.valid_encoding?).to be(true)
        end

        it 'handles invalid UTF-8 bytes without dropping valid non-ASCII text' do
          input = "<p>Röder\xFF</p>"
          expect(input.valid_encoding?).to be(false)
          output = SiteDiff::Sanitizer.new(input, config).sanitize
          expect(output).to include('Röder')
          expect(output.encoding).to eq(Encoding::UTF_8)
          expect(output.valid_encoding?).to be(true)
        end
      end
    end

    # it "doesn't strip HTML entities" do
    #   input = '<p>&mdash;</p>'
    #   output = SiteDiff::Sanitizer.new(input, {}).sanitize
    #   expect(output).to include "\u2014"
    # end

    it 'can perform a simple regex rule' do
      input = '<p>test something</p>'
      config = { 'sanitization' => [{ 'pattern' => 'something' }] }
      expect(SiteDiff::Sanitizer.new(input, config).sanitize).to include(
        '<p>test </p>'
      )
    end
    it 'can perform a more complex regex ' do
      input = '<input type="hidden" name="form_build_id" value="form-1cac6b5b6141a72b2382928249605fb1"/>'
      config = { 'sanitization' => [{
        'pattern' => '<input type="hidden" name="form_build_id" value="form-[a-zA-Z0-9_-]+" *\/?>',
        'selector' => 'input',
        'substitute' => '<input type="hidden" name="form_build_id" value="__form_build_id__">'
      }] }
      expect(SiteDiff::Sanitizer.new(input, config).sanitize).to include(
        '<input type="hidden" name="form_build_id" value="__form_build_id__"/>'
      )
    end
    it 'can perform regex replacements with captures' do
      input = '<img src="/file.jpeg-1cac1a72b2fb1" class="box"/>'
      config = { 'sanitization' => [{
        'pattern' => '(<img src="\/[a-zA-Z0-9.]+)-[1-9a-zA-Z_]*(".*>)',
        'substitute' => '\1\2'
      }] }
      expect(SiteDiff::Sanitizer.new(input, config).sanitize).to include(
        '<img src="/file.jpeg" class="box"/>'
      )
    end
    # FIXME: cleanup sanitize.rb such that the following (and similar tests for
    # transformations are more reasonable.
    it 'can perform an unwrap' do
      input = '<div class="parent"><p>X</p><p>Y</p></div>'
      config = { 'dom_transform' => [{
        'type' => 'unwrap',
        'selector' => '.parent'
      }] }
      output = SiteDiff::Sanitizer.new(input, config).sanitize
      expect(output).not_to include('parent')
      expect(output.gsub(/\s*/, '')).to include('<p>X</p><p>Y</p>')
    end
  end

  # TODO: regex captures, regex selectors
  # selector
  # transforms (unwrap, unwrap_root, remove_class, remove)
  # overall checks
  # spec out whether 'body' should be added? Frag vs Doc
end

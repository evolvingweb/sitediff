require "spec_helper"
require 'nokogiri'

describe SiteDiff::Sanitize do
  describe '::remove_spacing' do
    it 'normalizes space but only within text nodes' do
      doc = Nokogiri::HTML('<html><body  class="x  y">  z  </body></html>')
      SiteDiff::Sanitizer::remove_node_spacing(doc)
      expect(doc.to_s).to include '<html><body class="x  y"> z </body></html>'
    end
  end

  describe '::sanitize' do
    it "doesn't strip HTML entities" do
      input = '<p>&mdash;</p>'
      output = SiteDiff::Sanitize.sanitize(input, {})
      expect(output).to include "\u2014"
    end

    it "can perform a simple regex rule" do
      input = '<p>test something</p>'
      config = { 'sanitization' => [ { 'pattern' => 'something' } ] }
      expect(SiteDiff::Sanitize.sanitize(input, config)).to include(
        '<p>test </p>')
    end
    it "can perform a more complex regex " do
      input = '<input type="hidden" name="form_build_id" value="form-1cac6b5b6141a72b2382928249605fb1"/>'
      config = { 'sanitization' => [ {
        'pattern' => '<input type="hidden" name="form_build_id" value="form-[a-zA-Z0-9_-]+" *\/?>',
        'selector' => 'input',
        'substitute' => '<input type="hidden" name="form_build_id" value="__form_build_id__">'
      } ] }
      expect(SiteDiff::Sanitize.sanitize(input, config)).to include(
        '<input type="hidden" name="form_build_id" value="__form_build_id__"/>')
    end
    it "can perform regex replacements with captures" do
      input = '<img src="/file.jpeg-1cac1a72b2fb1" class="box"/>'
      config = { 'sanitization' => [ {
        'pattern' => '(<img src="\/[a-zA-Z0-9.]+)-[1-9a-zA-Z_]*(".*>)',
        'substitute' => '\1\2'
      } ] }
      expect(SiteDiff::Sanitize.sanitize(input, config)).to include(
        '<img src="/file.jpeg" class="box"/>')
    end
    # FIXME cleanup sanitize.rb such that the following (and similar tests for
    # transformations are more reasonable.
    it "can perform an unwrap" do
      input = '<div class="parent"><p>X</p><p>Y</p></div>'
      config = { 'dom_transform' => [ {
        'type' => 'unwrap',
        'selector' => '.parent'
      } ] }
      output = SiteDiff::Sanitize.sanitize(input, config)
      expect(output).not_to include('parent')
      expect(output.gsub(/\s*/, '')).to include('<p>X</p><p>Y</p>')
    end
  end

  # TODO:
  # regex captures, regex selectors
  # selector
  # transforms (unwrap, unwrap_root, remove_class, remove)
  # overall checks
  # spec out whether 'body' should be added? Frag vs Doc
end

require "spec_helper"
require 'nokogiri'

describe SiteDiff::Util::Sanitize do
  describe '::remove_spacing' do
    it 'normalizes space but only within text nodes' do
      doc = Nokogiri::HTML('<html><body  class="x  y">  z  </body></html>')
      SiteDiff::Util::Sanitize::remove_spacing(doc)
      expect(doc.to_s).to include '<html><body class="x  y"> z </body></html>'
    end
  end

  describe '::sanitize' do
    it "doesn't strip HTML entities" do
      input = '<p>&mdash;</p>'
      output = SiteDiff::Util::Sanitize.sanitize(input, {})
      expect(output).to include "\u2014"
    end
  end
end

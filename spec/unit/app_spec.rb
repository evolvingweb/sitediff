require "spec_helper"

describe SiteDiff::Page do
  describe "::is_prod?" do
    it 'works' do
      expect(SiteDiff::Page.is_prod?("http://amir-dev.tree.ewdev.ca/courses/search")).to be_false
      expect(SiteDiff::Page.is_prod?("http://www.mcgill.ca/study/2013-2014/courses/search")).to be_true
    end
  end
  describe "::complement_url" do
    it 'converts to prod properly' do
      input = "http://amir-dev.tree.ewdev.ca/courses/search"
      expect(SiteDiff::Page.complement_url(input)).to eq("http://www.mcgill.ca/study/2013-2014/courses/search") 
    end
    it 'converts to dev properly' do
      input = "http://www.mcgill.ca/study/2013-2014/courses/search"
      expect(SiteDiff::Page.complement_url(input)).to eq("http://amir-dev.tree.ewdev.ca/courses/search")
    end
  end
end


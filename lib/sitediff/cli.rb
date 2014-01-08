require 'thor'

module SiteDiff
  class Cli < Thor

    desc "diff URL", "Show html between URL and its pair"
    def diff(url)
      puts SiteDiff::Page.new(url).diff()
    end

    desc "complement URL", "Show complementary of given URL (swaps between prod and dev)"
    def complement(url)
      puts SiteDiff::Page.complement_url(url)
    end
  end
end

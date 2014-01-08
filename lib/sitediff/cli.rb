require 'thor'

module SiteDiff
  class Cli < Thor

    desc "diff URL", "Show html between URL and its pair"
    def diff(url)
      puts SiteDiff::Page.new(url).diff()
    end

    desc "pair URL", "Show corresponding pair URL (swaps between prod and dev)"
    def pair(url)
      puts SiteDiff::Page.complement_url(url)
    end
  end
end

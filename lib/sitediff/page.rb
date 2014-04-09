#NOTE currently not used
require 'open-uri'
require 'sitediff/util/diff'

module SiteDiff

  class Page
    attr_accessor :url

    def initialize(url)
      @url = url
      if is_prod?()
        @site = SiteDiff::Config.prod_site
      elsif is_dev?()
        @site = SiteDiff::Config.dev_site
      else
        raise "URL doesn't correspond to either dev or prod site."
      end
    end

    def html
      options = {}
      if auth = @site["auth_basic"]
        options = { :http_basic_authentication => [@site["auth_basic"]["user"], @site["auth_basic"]["password"]] }
      end
      @html ||= open(@url, options).read
    end

    def doc
      @doc ||= Nokogiri::HTML(@html)
    end

    def self.is_prod?(url)
      return url.index(SiteDiff::Config.prod_url) == 0
    end

    def self.is_dev?(url)
      return url.index(SiteDiff::Config.dev_url) == 0
    end

    def self.complement_url(url)
      dev_url = SiteDiff::Config.dev_url
      prod_url = SiteDiff::Config.prod_url

      return is_prod?(url) ? url.gsub(prod_url, dev_url) : url.gsub(dev_url, prod_url)
    end

    def complement()
      @complement ||= self.class.new(self.class.complement_url(@url))
    end

    def is_prod?()
      self.class.is_prod?(@url)
    end

    def is_dev?()
      self.class.is_dev?(@url)
    end

    # returns a tuple of [prod_page, dev_page]
    def prod_dev_pair()
      return is_prod? ? [self, complement] : [complement, self]
    end

    def diff()
      prod, dev = prod_dev_pair()
      diff = SiteDiff::Util::Diff::html_diff(prod.html(), dev.html())
      diff.gsub!("Only in Old</span>", "Only in Prod</span> <a href='#{prod.url}'>#{prod.url}</a> <br />")
      diff.gsub!("Only in New</span>", "Only in Dev</span> <a href='#{dev.url}'>#{dev.url}</a>")
      diff
    end
  end
end

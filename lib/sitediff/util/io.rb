module SiteDiff
  class SiteDiffReadFailure < Exception; end
  module Util
    module IO
      module_function

      def read(url, params)
        if (url.match(/^http/))
          file = open(url, params)
        else
          file = File.open(url, 'r:UTF-8')
        end
        if file.nil?
          return []
        end
        str = file.read
        unless str.valid_encoding?
          str = str.encode('utf-8', 'binary', :invalid => :replace, :undef => :replace)
        end
        return str
      rescue OpenURI::HTTPError => e
        raise SiteDiffReadFailure.new(e.message)
      rescue Errno::ENOENT => e
        raise SiteDiffReadFailure.new(e.message)
      end
    end
  end
end


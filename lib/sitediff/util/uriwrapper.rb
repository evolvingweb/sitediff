class SiteDiff
  class SiteDiffReadFailure < Exception; end

  module Util
    # @class UriWrapper is a workaround for open() rejecting URIs with credentials
    # eg user:password@hostname.com
    class UriWrapper
      def initialize(uri)
        @uri = uri.respond_to?(:scheme) ? uri : URI.parse(uri)
      end

      def user
        @uri.user
      end

      def password
        @uri.password
      end

      def to_s
        uri_no_credentials = @uri.clone
        uri_no_credentials.user = nil
        uri_no_credentials.password = nil
        ret = uri_no_credentials.to_s
        return ret
      end

      def +(path)
        uri = @uri.dup
        uri.path += '/' + path
        return self.class.new(uri)
      end

      def read
        file = nil
        if @uri.scheme == nil
          file = File.open(@uri.to_s, 'r:UTF-8')
        else
          file = open(@uri)
        end
        str = file.read
        unless str.valid_encoding?
          str = str.encode('utf-8', 'binary', :invalid => :replace,
            :undef => :replace)
        end
        return str
      rescue OpenURI::HTTPError => e
        raise SiteDiffReadFailure.new(e.message)
      rescue Errno::ENOENT => e
        raise SiteDiffReadFailure.new(e.message)
      ensure
        file.close if file
      end
    end
  end
end

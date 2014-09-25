class SiteDiff
  module Util
    # @class UriWrapper is a workaround for open() rejecting URIs with credentials
    # eg user:password@hostname.com
    class UriWrapper
      def initialize(uri)
        @uri = URI.parse(uri)
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
    end
  end
end

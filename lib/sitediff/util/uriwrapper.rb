require 'typhoeus'

class SiteDiff
  class SiteDiffReadFailure < Exception; end

  module Util
    # @class UriWrapper is a workaround for open() rejecting URIs with credentials
    # eg user:password@hostname.com
    class UriWrapper
      # This lets us treat errors or content as one object
      class ReadResult < Struct.new(:content, :error)
        def initialize(cont, err = nil)
          super(cont, err)
        end
        def self.error(err); new(nil, err); end
      end

      def initialize(uri)
        @uri = uri.respond_to?(:scheme) ? uri : URI.parse(uri)
      end

      def user
        @uri.user
      end

      def password
        @uri.password
      end

      def no_credentials
        uri_no_credentials = @uri.clone
        uri_no_credentials.user = nil
        uri_no_credentials.password = nil
        return uri_no_credentials
      end

      def to_s
        return no_credentials.to_s
      end

      def +(path)
        uri = @uri.dup
        path != '' && uri.path += '/' + path
        return self.class.new(uri)
      end

      # Reads a file and yields to the completion handler, see .queue()
      def read_file(&handler)
        File.open(@uri.to_s, 'r:UTF-8') { |f| yield ReadResult.new(f.read) }
      rescue Errno::ENOENT, Errno::ENOTDIR, Errno::EACCES => e
        yield ReadResult.error(e.message)
      end

      # Returns the encoding of an HTTP response from headers , nil if not
      # specified.
      def http_encoding(http_headers)
        if content_type = http_headers['Content-Type']
          if md = /;\s*charset=([-\w]*)/.match(content_type)
            return md[1]
          end
        end
      end

      # Returns a Typhoeus::Request to fetch @uri
      #
      # Completion callbacks of the request wrap the given handler which is
      # assumed to accept a single ReadResult argument.
      def typhoeus_request(&handler)
        params = {
          :connecttimeout => 3,   # Don't hang on servers that don't exist
          :followlocation => true # Follow HTTP redirects (code 301 and 302)
        }
        # Allow basic auth
        params[:userpwd] = @uri.user + ':' + @uri.password if @uri.user

        req = Typhoeus::Request.new(self.to_s, params)

        req.on_success do |resp|
          body = resp.body
          # Typhoeus does not respect HTTP headers when setting the encoding
          # resp.body; coerce if possible.
          if encoding = http_encoding(resp.headers)
            body.force_encoding(encoding)
          end
          yield ReadResult.new(body)
        end

        req.on_failure do |resp|
          yield ReadResult.error(resp.status_message ||
                                 "Unknown HTTP error in fetching #{@uri}")
        end

        req
      end

      # Queue reading this URL, with a completion handler to run after.
      #
      # The handler should be callable as handler[ReadResult].
      #
      # This method may choose not to queue the request at all, but simply
      # execute right away.
      def queue(hydra, &handler)
        if @uri.scheme == nil
          read_file(&handler)
        else
          hydra.queue(typhoeus_request(&handler))
        end
      end
    end
  end
end

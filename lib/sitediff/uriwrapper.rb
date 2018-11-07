# frozen_string_literal: true

require 'sitediff/exception'
require 'typhoeus'
require 'addressable/uri'

class SiteDiff
  class SiteDiffReadFailure < SiteDiffException; end

  class UriWrapper
    DEFAULT_CURL_OPTS = {
      connecttimeout: 3,     # Don't hang on servers that don't exist
      followlocation: true,  # Follow HTTP redirects (code 301 and 302)
      headers: {
        'User-Agent' => 'Sitediff - https://github.com/evolvingweb/sitediff'
      }
    }.freeze

    # This lets us treat errors or content as one object
    class ReadResult
      attr_accessor :content, :error_code, :error

      def initialize(content = nil)
        @content = content
        @error = nil
        @error_code = nil
      end

      def self.error(err, code = nil)
        res = new
        res.error_code = code
        res.error = err
        res
      end
    end

    def initialize(uri, curl_opts = DEFAULT_CURL_OPTS)
      @uri = uri.respond_to?(:scheme) ? uri : Addressable::URI.parse(uri)
      # remove trailing '/'s from local URIs
      @uri.path.gsub!(%r{/*$}, '') if local?
      @curl_opts = curl_opts
    end

    def user
      @uri.user
    end

    def password
      @uri.password
    end

    def to_s
      uri = @uri.dup
      uri.user = nil
      uri.password = nil
      uri.to_s
    end

    # Is this a local filesystem path?
    def local?
      @uri.scheme.nil?
    end

    # FIXME: this is not used anymore
    def +(path)
      # 'path' for SiteDiff includes (parts of) path, query, and fragment.
      sep = ''
      sep = '/' if local? || @uri.path.empty?
      self.class.new(@uri.to_s + sep + path)
    end

    # Reads a file and yields to the completion handler, see .queue()
    def read_file
      File.open(@uri.to_s, 'r:UTF-8') { |f| yield ReadResult.new(f.read) }
    rescue Errno::ENOENT, Errno::ENOTDIR, Errno::EACCES, Errno::EISDIR => e
      yield ReadResult.error(e.message)
    end

    # Returns the encoding of an HTTP response from headers , nil if not
    # specified.
    def http_encoding(http_headers)
      if (content_type = http_headers['Content-Type'])
        if (md = /;\s*charset=([-\w]*)/.match(content_type))
          md[1]
        end
      end
    end

    # Returns a Typhoeus::Request to fetch @uri
    #
    # Completion callbacks of the request wrap the given handler which is
    # assumed to accept a single ReadResult argument.
    def typhoeus_request
      params = @curl_opts.dup
      # Allow basic auth
      params[:userpwd] = @uri.user + ':' + @uri.password if @uri.user

      req = Typhoeus::Request.new(to_s, params)

      req.on_success do |resp|
        body = resp.body
        # Typhoeus does not respect HTTP headers when setting the encoding
        # resp.body; coerce if possible.
        if (encoding = http_encoding(resp.headers))
          body.force_encoding(encoding)
        end
        yield ReadResult.new(body)
      end

      req.on_failure do |resp|
        msg = 'Unknown Error'
        msg = resp.status_message if resp&.status_message
        yield ReadResult.error("HTTP error #{@uri}: #{msg}", resp.response_code)
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
      if local?
        read_file(&handler)
      else
        hydra.queue(typhoeus_request(&handler))
      end
    end
  end
end

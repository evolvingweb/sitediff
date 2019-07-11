# frozen_string_literal: true

require 'sitediff/exception'
require 'typhoeus'
require 'addressable/uri'

class SiteDiff
  class SiteDiffReadFailure < SiteDiffException; end

  # SiteDiff URI Wrapper.
  class UriWrapper
    # TODO: Move these CURL OPTS to Config.DEFAULT_CONFIG.
    DEFAULT_CURL_OPTS = {
      # Don't hang on servers that don't exist.
      connecttimeout: 3,
      # Follow HTTP redirects (code 301 and 302).
      followlocation: true,
      headers: {
        'User-Agent' => 'Sitediff - https://github.com/evolvingweb/sitediff'
      }
    }.freeze

    # This lets us treat errors or content as one object
    class ReadResult
      attr_accessor :encoding, :content, :error_code, :error

      ##
      # Creates a ReadResult.
      def initialize(content = nil, encoding = 'utf-8')
        @content = content
        @encoding = encoding
        @error = nil
        @error_code = nil
      end

      ##
      # Creates a ReadResult with an error.
      def self.error(message, code = nil)
        res = new
        res.error_code = code
        res.error = message
        res
      end
    end

    ##
    # Creates a UriWrapper.
    def initialize(uri, curl_opts = DEFAULT_CURL_OPTS, debug = true)
      @uri = uri.respond_to?(:scheme) ? uri : Addressable::URI.parse(uri)
      # remove trailing '/'s from local URIs
      @uri.path.gsub!(%r{/*$}, '') if local?
      @curl_opts = curl_opts
      @debug = debug
    end

    ##
    # Returns the "user" part of the URI.
    def user
      @uri.user
    end

    ##
    # Returns the "password" part of the URI.
    def password
      @uri.password
    end

    ##
    # Converts the URI to a string.
    def to_s
      uri = @uri.dup
      uri.user = nil
      uri.password = nil
      uri.to_s
    end

    ##
    # Is this a local filesystem path?
    def local?
      @uri.scheme.nil?
    end

    ## What does this one do?
    # FIXME: this is not used anymore
    def +(other)
      # 'path' for SiteDiff includes (parts of) path, query, and fragment.
      sep = ''
      sep = '/' if local? || @uri.path.empty?
      self.class.new(@uri.to_s + sep + other)
    end

    ##
    # Reads a file and yields to the completion handler, see .queue()
    def read_file
      File.open(@uri.to_s, 'r:UTF-8') { |f| yield ReadResult.new(f.read) }
    rescue Errno::ENOENT, Errno::ENOTDIR, Errno::EACCES, Errno::EISDIR => e
      yield ReadResult.error(e.message)
    end

    # Returns the encoding of an HTTP response from headers , nil if not
    # specified.
    def charset_encoding(http_headers)
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
        if (encoding = charset_encoding(resp.headers))
          body.force_encoding(encoding)
        end
        # Should be wrapped with rescue I guess? Maybe this entire function?
        # Should at least be an option in the Cli to disable this.
        # "stop on first error"
        begin
          yield ReadResult.new(body, encoding)
        rescue ArgumentError => e
          raise if @debug

          yield ReadResult.error(
            "Parsing error for #{@uri}: #{e.message}"
          )
        rescue StandardError => e
          raise if @debug

          yield ReadResult.error(
            "Unknown parsing error for #{@uri}: #{e.message}"
          )
        end
      end

      req.on_failure do |resp|
        if resp&.status_message
          msg = resp.status_message
          yield ReadResult.error(
            "HTTP error when loading #{@uri}: #{msg}",
            resp.response_code
          )
        elsif (msg = resp.options[:return_code])
          yield ReadResult.error(
            "Connection error when loading #{@uri}: #{msg}",
            resp.response_code
          )
        else
          yield ReadResult.error(
            "Unknown error when loading #{@uri}: #{msg}",
            resp.response_code
          )
        end
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

require 'gdbm'

class SiteDiff
  module Util
    # A typhoeus cache, backed by DBM
    class Cache
      def initialize(file)
        @dbm = GDBM.new(file)
      end

      # Older Typhoeus doesn't have cache_key
      def cache_key(req)
        return req.cache_key if req.respond_to?(:cache_key)
        return Marshal.dump([req.base_url, req.options])
      end

      def get(req)
        resp = @dbm[cache_key(req)] or return nil
        Marshal.load(resp)
      end

      def set(req, resp)
        @dbm[cache_key(req)] = Marshal.dump(resp)
      end
    end
  end
end

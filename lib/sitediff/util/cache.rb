class SiteDiff
  module Util
    # A typhoeus cache, backed by DBM
    class Cache
      def initialize(file)
        # Default to GDBM, if we have it, we don't want pag/dir files
        begin
          require 'gdbm'
          @dbm = GDBM.new(file)
        rescue LoadError
          require 'dbm'
          @dbm = DBM.new(file)
        end
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

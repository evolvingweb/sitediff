# frozen_string_literal: true

require 'set'

class SiteDiff
  class Cache
    DEFAULT_FILENAME = 'cache.db'

    attr_accessor :read_tags, :write_tags

    def initialize(opts = {})
      @file = opts[:file] || DEFAULT_FILENAME
      @create = opts[:create]
      @read_tags = Set.new
      @write_tags = Set.new
    end

    def close
      @dbm.close if defined? @dbm
    end

    # Is a tag cached?
    def tag?(tag)
      open
      @dbm[tag.to_s]
    end

    def get(tag, path)
      return nil unless @read_tags.include? tag

      open || (return nil)
      val = @dbm[key(tag, path)]
      val && Marshal.load(val)
    end

    def set(tag, path, result)
      return unless @write_tags.include? tag

      open || return
      @dbm[tag.to_s] = 'TRUE'
      @dbm[key(tag, path)] = Marshal.dump(result)
    end

    private

    def key(tag, path)
      # Ensure encoding stays the same!
      Marshal.dump([tag, path.encode('UTF-8')])
    end

    # Ensure the DB is open
    def open
      # DBM adds an extra .db, ugh
      return false unless @create || File.exist?(@file) ||
                          File.exist?(@file + '.db')
      return true if defined? @dbm

      begin
        require 'gdbm'
        @dbm = GDBM.new(@file)
      rescue LoadError
        require 'dbm'
        @dbm = DBM.new(@file)
      end
      true
    end
  end
end

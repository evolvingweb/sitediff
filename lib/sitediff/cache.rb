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

  def close; @dbm.close; end

  # Is a tag cached?
  def tag?(tag)
    open
    @dbm[tag.to_s]
  end

  def get(tag, path)
    return nil unless @read_tags.include? tag
    open or return nil
    val = @dbm[key(tag, path)]
    return val && Marshal.load(val)
  end

  def set(tag, path, result)
    return unless @write_tags.include? tag
    open or return
    @dbm[tag.to_s] = 'TRUE'
    @dbm[key(tag, path)] = Marshal.dump(result)
  end

private
  def key(tag, path)
    Marshal.dump([tag, path])
  end

  # Ensure the DB is open
  def open
    return false unless @create || File.exist?(@file)
    return true if defined? @dbm

    begin
      require 'gdbm'
      @dbm = GDBM.new(@file)
    rescue LoadError
      require 'dbm'
      @dbm = DBM.new(@file)
    end
    return true
  end
end
end

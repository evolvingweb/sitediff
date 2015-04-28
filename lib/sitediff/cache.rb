require 'set'

class SiteDiff
class Cache
  attr_accessor :read_tags, :write_tags

  def initialize(file = nil)
    file ||= 'cache.db'

    begin
      require 'gdbm'
      @dbm = GDBM.new(file)
    rescue LoadError
      require 'dbm'
      @dbm = DBM.new(file)
    end

    @read_tags = Set.new
    @write_tags = Set.new
  end

  # Is a tag cached?
  def tag?(tag)
    @dbm[tag.to_s]
  end

  def get(tag, path)
    return nil unless @read_tags.include? tag
    val = @dbm[key(tag, path)]
    return val && Marshal.load(val)
  end

  def set(tag, path, result)
    return unless @write_tags.include? tag
    @dbm[tag.to_s] = 'TRUE'
    @dbm[key(tag, path)] = Marshal.dump(result)
  end

private
  def key(tag, path)
    Marshal.dump([tag, path])
  end
end
end

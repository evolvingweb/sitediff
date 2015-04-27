require 'set'

class SiteDiff
class Cache
  Read = 1
  Write = 2

  def initialize(file = nil)
    file ||= 'cache.db'

    begin
      require 'gdbm'
      @dbm = GDBM.new(file)
    rescue LoadError
      require 'dbm'
      @dbm = DBM.new(file)
    end
    @rtags = Set.new
    @wtags = Set.new
  end

  # Is a tag cached?
  def tag?(tag)
    @dbm[tag.to_s]
  end

  def use(dir, *tags)
    tags.each do |tag|
      @rtags << tag if dir == Read
      @wtags << tag if dir == Write
    end
  end

  def get(tag, path)
    return nil unless @rtags.include? tag
    val = @dbm[key(tag, path)]
    return val && Marshal.load(val)
  end

  def set(tag, path, result)
    return unless @wtags.include? tag
    @dbm[tag.to_s] = 'TRUE'
    @dbm[key(tag, path)] = Marshal.dump(result)
  end

private
  def key(tag, path)
    Marshal.dump([tag, path])
  end
end
end

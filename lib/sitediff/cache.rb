class SiteDiff
class Cache
  Read = 1
  Write = 2
  RW = Read | Write

  def initialize(file)
    begin
      require 'gdbm'
      @dbm = GDBM.new(file)
    rescue LoadError
      require 'dbm'
      @dbm = DBM.new(file)
    end
    @rmap = {}
    @wmap = {}
  end

  # Set cache mapping
  def map(dir, tag, dest = nil)
    dest = tag
    @rmap[tag] = dest if dir & Read != 0
    @wmap[tag] = dest if dir & Write != 0
  end

  def get(tag, path)
    return nil unless intern = @rmap[tag]
    val = @dbm[key(intern, path)]
    return val && Marshal.load(val)
  end

  def set(tag, path, result)
    return unless intern = @wmap[tag]
    @dbm[key(intern, path)] = Marshal.dump(result)
  end

private
  def key(intern, path)
    Marshal.dump([intern, path])
  end
end
end

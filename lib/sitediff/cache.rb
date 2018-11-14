# frozen_string_literal: true

require 'set'
require 'fileutils'

class SiteDiff
  class Cache
    attr_accessor :read_tags, :write_tags

    def initialize(opts = {})
      @dir = opts[:dir] || '.'
      @create = opts[:create]
      @read_tags = Set.new
      @write_tags = Set.new
    end

    # Is a tag cached?
    def tag?(tag)
      File.directory?(File.join(@dir, "snapshot", tag.to_s))
    end

    def get(tag, path)
      return nil unless @read_tags.include? tag

      filename = File.join(@dir, "snapshot", tag.to_s, *path.split(File::SEPARATOR))
      if File.directory?(filename)
        filename = File.join(filename, "index.html")
      end
      Marshal.load(File.read(filename))
    end

    def set(tag, path, result)
      return unless @write_tags.include? tag

      filename = File.join(@dir, "snapshot", tag.to_s, *path.split(File::SEPARATOR))
      if File.directory?(filename)
        filename = File.join(filename, "index.html")
      end
      filepath = Pathname.new(filename)
      if not filepath.dirname.directory?
        begin
          filepath.dirname.mkpath
        rescue Errno::EEXIST
          curdir = filepath
          while not curdir.exist?
            curdir = curdir.parent
          end
          tempname = curdir.dirname + (curdir.basename.to_s + '.temporary')
          # May cause problems if action is not atomic!
          # Move existing file to dir/index.html first
          # Not robust! Should generate an UUID or something.
          curdir.rename(tempname)
          filepath.dirname.mkpath
          tempname.rename(curdir + 'index.html')
        end
      end
      File.open(filename, 'w') { |file| file.write(Marshal.dump(result)) }
    end

    def key(tag, path)
      # Ensure encoding stays the same!
      Marshal.dump([tag, path.encode('UTF-8')])
    end
  end
end

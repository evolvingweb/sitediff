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
      File.directory?(File.join(@dir, 'snapshot', tag.to_s))
    end

    def get(tag, path)
      return nil unless @read_tags.include? tag

      filename = File.join(@dir, 'snapshot', tag.to_s, *path.split(File::SEPARATOR))

      filename = File.join(filename, 'index.html') if File.directory?(filename)
      Marshal.load(File.read(filename))
    end

    def set(tag, path, result)
      return unless @write_tags.include? tag

      filename = File.join(@dir, 'snapshot', tag.to_s, *path.split(File::SEPARATOR))

      filename = File.join(filename, 'index.html') if File.directory?(filename)
      filepath = Pathname.new(filename)
      unless filepath.dirname.directory?
        begin
          filepath.dirname.mkpath
        rescue Errno::EEXIST
          curdir = filepath
          curdir = curdir.parent until curdir.exist?
          tempname = curdir.dirname + (curdir.basename.to_s + '.temporary')
          # May cause problems if action is not atomic!
          # Move existing file to dir/index.html first
          # Not robust! Should generate an UUID or something.
          SiteDiff.log "Overwriting file #{tempname}", :warn if File.exist?(tempname)
          curdir.rename(tempname)
          filepath.dirname.mkpath
          # Should only happen in strange situations such as when the path
          # is foo/index.html/bar (i.e., index.html is a directory)
          SiteDiff.log "Overwriting file #{tempname}", :warn if (curdir + 'index.html').exist?
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

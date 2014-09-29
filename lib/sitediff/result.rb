class SiteDiff
  class Result < Struct.new(:path, :before, :after, :error)
    STATUS_SUCCESS  = 0   # Identical before and after
    STATUS_FAILURE  = 1   # Different before and after
    STATUS_ERROR    = 2   # Couldn't fetch page
    STATUS_TEXT = %w[success failure error]

    attr_reader :status, :diff

    def initialize(*args)
      super
      if error
        @status = STATUS_ERROR
      else
        @diff = Util::Diff::html_diffy(before, after)
        @status = @diff ? STATUS_FAILURE : STATUS_SUCCESS
      end
    end

    def success?
      status == STATUS_SUCCESS
    end

    # Textual representation of the status
    def status_text
      return STATUS_TEXT[status]
    end

    # Printable URL
    def url(prefix)
      prefix.to_s + '/' + path
    end

    # Filename to store the diff under
    def filename
      "diff_" + path.gsub('/', '_').gsub('#', '___') + ".html"
    end

    # Text of the link in the HTML report
    def link
      case status
      when STATUS_ERROR then error
      when STATUS_SUCCESS then status_text
      when STATUS_FAILURE then "<a href='#{filename}'>DIFF</a>"
      end
    end

    # Log the result to the terminal
    def log
      case status
      when STATUS_SUCCESS then
        SiteDiff::log "SUCCESS: #{path}", :green
      when STATUS_ERROR then
        SiteDiff::log "ERROR (#{error}): #{path}", :yellow
      when STATUS_FAILURE then
        SiteDiff::log "FAILURE: #{path}", :red
        puts Util::Diff::terminal_diffy(before, after)
      end
    end

    # Dump the result to a file
    def dump(dir)
      dump_path = File.join(dir, filename)
      File.open(dump_path, 'w') do |f|
        f.write(Util::Diff::generate_diff_output(self))
      end
    end
  end
end

# frozen_string_literal: true

require 'sitediff'
require 'sitediff/diff'
require 'digest/sha1'
require 'fileutils'

class SiteDiff
  # SiteDiff Result Object.
  class Result < Struct.new(:path, :before, :after, :before_encoding, :after_encoding, :error, :verbose)
    STATUS_SUCCESS  = 0   # Identical before and after
    STATUS_FAILURE  = 1   # Different before and after
    STATUS_ERROR    = 2   # Couldn't fetch page
    STATUS_TEXT = %w[success failure error].freeze

    attr_reader :status, :diff

    def initialize(*args)
      super
      if error
        @status = STATUS_ERROR
      else
        if !before_encoding || !after_encoding
          @diff = Diff.binary_diffy(before, after, before_encoding, after_encoding)
        else
          @diff = Diff.html_diffy(before, after)
        end
        @status = @diff ? STATUS_FAILURE : STATUS_SUCCESS
      end
    end

    def success?
      status == STATUS_SUCCESS
    end

    # Textual representation of the status
    def status_text
      STATUS_TEXT[status]
    end

    # Printable URL
    def url(tag, prefix, cache)
      base = cache.read_tags.include?(tag) ? "/cache/#{tag}" : prefix
      base.to_s + path
    end

    # Filename to store diff
    def filename
      File.join(SiteDiff::DIFFS_DIR, Digest::SHA1.hexdigest(path) + '.html')
    end

    # Text of the link in the HTML report.
    # TODO: Return URL only and let the template render the link.
    # TODO: Return NULL when there is no link.
    def link
      case status
      when STATUS_ERROR then error
      when STATUS_SUCCESS then status_text
      when STATUS_FAILURE then "<a href='#{filename}'>DIFF</a>"
      end
    end

    # Log the result to the terminal
    def log(verbose = true)
      case status
      when STATUS_SUCCESS then
        SiteDiff.log path, :diff_success, 'UNCHANGED'
      when STATUS_ERROR then
        SiteDiff.log path, :warn, "ERROR (#{error})"
      when STATUS_FAILURE then
        SiteDiff.log path, :diff_failure, 'CHANGED'
        puts Diff.terminal_diffy(before, after) if verbose
      end
    end

    # Dump the result to a file
    def dump(dir)
      dump_path = File.join(dir, filename)
      base = File.dirname(dump_path)
      FileUtils.mkdir_p(base) unless File.exist?(base)
      File.open(dump_path, 'w') do |f|
        f.write(Diff.generate_diff_output(self))
      end
    end
  end
end

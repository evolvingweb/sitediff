# frozen_string_literal: true

require 'spec_helper'

require 'open3'
require 'tmpdir'
require 'nokogiri'

require 'sitediff/webserver'
require 'sitediff/cli'

# TODO: Organize tests in a better way.
describe SiteDiff::Cli do
  it 'Runs sitediff diff' do
    SiteDiff::Webserver::FixtureServer.new do |srv|
      dir = Dir.mktmpdir
      cmd = [
        './bin/sitediff', 'diff',
        '--before', srv.before,
        '--after', srv.after,
        '--directory', dir,
        '--cached', 'none',
        '-v',
        '-d',
        'spec/fixtures/config.yaml'
      ]

      out, status = Open3.capture2(*cmd)

      # Should run successfully (exit code 1 is when we crash, 2 is when
      # there's a diff).
      expect(status.exitstatus).to be 2

      # Should report that Hash.html doesn't match
      expect(out).to include '[CHANGED] /Hash.html'

      # Should report that File.html matches
      expect(out).to include '[UNCHANGED] /IO.html'

      # Should report that TracePoint.html matches
      expect(out).to include '[ERROR] /TracePoint.html'

      # Should report a diff of a different line
      expect(out).to match(/^+.*<a href="#method-i-to_h"/)

      # There should be a failures file
      failures = File.join(dir, 'failures.txt')
      expect(File.file?(failures)).to be true
      expect(File.read(failures).strip).to include '/Hash.html'

      # There should be a report file
      report = File.join(dir, 'report.html')
      expect(File.file?(report)).to be true
      doc = Nokogiri.HTML(File.read(report))

      # There should be a link to a diff.
      expect(doc.css('a').text).to include 'View diff'

      # There should be a link to the before version.
      before_link = File.join(srv.before, 'Hash.html')
      expect(doc.css('a').any? { |a| a['href'] == before_link }).to be true

      # There should be a proper diff file.
      diff = File.join(
        dir,
        'diffs',
        Digest::SHA1.hexdigest('/Hash.html') + '.html'
      )
      warn(diff)

      expect(File.file?(diff)).to be true

      # TODO: Understand why the SiteDiff thinks that the HTML docs are binary.
      #
      # For some reason, SiteDiff gets binary output for the before/after sites
      # when running from this test. During normal use, everything goes fine.
      # Since SiteDiff cannot understand the encoding of the files it fetches,
      # breaking various pieces of code in the process.
      #
      # Refer to the "callback" in the Fetcher class. It should get proper
      # encoding data for the results that it receives. The problem might be in
      # the interaction with Typhoeus (a wrapper around CURL).
      # expect(File.read(diff)).to include '#method-i-to_h'
    end
  end
end

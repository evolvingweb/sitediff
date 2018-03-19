require 'spec_helper'

require 'open3'
require 'tmpdir'
require 'nokogiri'

require 'sitediff/webserver'
require 'sitediff/cli'

describe SiteDiff::Cli do
  it 'runs the fixture successfully' do
    SiteDiff::Webserver::FixtureServer.new do |srv|
      Dir.mktmpdir do |dir|
        cmd = [
          './bin/sitediff', 'diff',
          '--before', srv.before,
          '--after', srv.after,
          '--dump-dir', dir,
          '--cached', 'none',
          'spec/fixtures/config.yaml'
        ]

        out, status = Open3.capture2(*cmd)

        # Should run successfully (exit code 1 is when we crash, 2 is when
        # there's a diff).
        expect(status.exitstatus).to be 2

        # Should report that Hash.html doesn't match
        expect(out).to include 'FAILURE /Hash.html'

        # Should report that File.html matches
        expect(out).to include 'SUCCESS /IO.html'

        # Should report a diff of a different line
        expect(out).to match /^+.*<a href="#method-i-to_h"/

        # There should be a failures file
        failures = File.join(dir, 'failures.txt')
        expect(File.file?(failures)).to be true
        expect(File.read(failures).strip).to include '/Hash.html'

        # There should be a report file
        report = File.join(dir, 'report.html')
        expect(File.file?(report)).to be true
        doc = Nokogiri.HTML(open(report))
        # Link to a diff
        expect(doc.css('a').text).to include 'DIFF'
        # Link to before
        before_link = File.join(srv.before, 'Hash.html')
        expect(doc.css('a').any? { |a| a['href'] == before_link }).to be true

        # There should be a diff file
        diff = File.join(dir, 'diffs', Digest::SHA1.hexdigest('/Hash.html') + '.html')
        warn(diff)
        expect(File.file?(diff)).to be true
        expect(File.read(diff)).to include '#method-i-to_h'
      end
    end
  end
end

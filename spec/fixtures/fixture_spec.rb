require 'spec_helper'

require 'open3'
require 'tmpdir'
require 'nokogiri'

require 'sitediff/util/webserver'
require 'sitediff/cli'

describe SiteDiff::Cli do
  it 'runs the fixture successfully' do
    SiteDiff::Util::FixtureServer.new do |srv|
      Dir.mktmpdir do |dir|
        cmd = [
          './bin/sitediff', 'diff',
          '--before', srv.before,
          '--after', srv.after,
          '--dump-dir', dir,
          'spec/fixtures/config.yaml'
        ]

        out, status = Open3.capture2(*cmd)

        # Should run successfully
        expect(status.success?).to be true

        # Should report that Hash.html doesn't match
        expect(out).to include 'FAILURE /Hash.html'

        # Should report that File.html matches
        expect(out).to include 'SUCCESS /IO.html'

        # Should report a diff of a different line
        expect(out).to match /^+.*<a href="#method-i-to_h"/

        # There should be a failures file
        failures = 'failures.txt'
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
        diff = File.join(dir, 'diffs', 'Hash.html.html')
        expect(File.file?(diff)).to be true
        expect(File.read(diff)).to include '#method-i-to_h'
      end
    end
  end
end

require 'thor'
require 'sitediff/util/diff'
require 'sitediff/util/sanitize'
require 'sitediff/util/io'
require 'open-uri'
require 'uri'

class SiteDiff
  # @class UriWrapper is a workaround for open() rejecting URIs with credentials
  # eg user:password@hostname.com
  class UriWrapper
    def initialize(uri)
      @uri = URI.parse(uri)
    end

    def user
      @uri.user
    end

    def password
      @uri.password
    end

    def to_s
      uri_no_credentials = @uri.clone
      uri_no_credentials.user = nil
      uri_no_credentials.password = nil
      ret = uri_no_credentials.to_s
      return ret
    end
  end

  class Cli < Thor
    # Thor, by default, exits with 0 no matter what!
    def self.exit_on_failure?
      true
    end

    option 'dump-dir',
      :type => :string,
      :default => "./output/",
      :banner => "Location to write the output to."
    option 'paths-from-file',
      :type => :string,
      :banner => "File listing URL paths to run on against <before> and <after> sites."
    option 'paths-from-failures',
      :type => :boolean,
      :default => FALSE,
      :banner => "Equivalent to --paths-from-file=<DUMPDIR>/failures.txt"
    option 'before-url',
      :required => true,
      :type => :string,
      :banner => "URL used to fetch the before HTML. Acts as a prefix to specified paths"
    option 'after-url',
      :required => true,
      :type => :string,
      :banner => "URL used to fetch the after HTML. Acts as a prefix to specified paths."
    option 'before-url-report',
      :type => :string,
      :default => "",
      :banner => "Before URL to use for reporting purposes. Useful if port forwarding."
    option 'after-url-report',
      :type => :string,
      :default => "",
      :banner => "After URL to use for reporting purposes. Useful if port forwarding."
    #FIXME description is not correct
    desc "diff [OPTIONS] <BEFORE> <AFTER> [CONFIGFILES]", "Perform systematic diff on given URLs"
    def diff(*config_files)
      SiteDiff.new(options, config_files)
    end
  end
end

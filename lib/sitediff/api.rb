# frozen_string_literal: true

require 'sitediff'
require 'sitediff/cache'
require 'sitediff/config'
require 'sitediff/config/creator'
require 'sitediff/config/preset'
require 'sitediff/fetch'
require 'sitediff/webserver/resultserver'

class SiteDiff
  ##
  # Sitediff API interface.
  class Api
    ##
    # Intialize a SiteDiff project.
    #
    # Calling:
    #   SiteDiff::Api.init(
    #     depth: 3,
    #     directory: 'sitediff',
    #     concurrency: 3,
    #     interval: 0,
    #     include: nil,
    #     exclude: '*.pdf',
    #     preset: 'drupal',
    #     curl_opts: {timeout: 60},
    #     crawl: false
    #   )
    def self.init(options)
      # Prepare a config object and write it to the file system.
      creator = SiteDiff::Config::Creator.new(options[:debug], options[:before_url], options[:after_url])
      include_regex = Config.create_regexp(options[:include])
      exclude_regex = Config.create_regexp(options[:exclude])
      creator.create(
        depth: options[:depth],
        directory: options[:directory],
        concurrency: options[:concurrency],
        interval: options[:interval],
        include: include_regex,
        exclude: exclude_regex,
        preset: options[:preset],
        curl_opts: options[:curl_opts]
      )
      SiteDiff.log "Created #{creator.config_file.expand_path}", :success

      # TODO: implement crawl ^^^
      # Discover paths, if enabled.
      # if options[:crawl]
      #   crawl(creator.config_file)
      #   SiteDiff.log 'You can now run "sitediff diff".', :success
      # else
      #   SiteDiff.log 'Run "sitediff crawl" to discover paths. You should then be able to run "sitediff diff".', :info
      # end

    end
  end
end

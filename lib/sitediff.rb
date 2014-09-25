#!/bin/env ruby
require 'sitediff/cli.rb'
#require 'sitediff/page.rb'
require 'sitediff/config.rb'

module SiteDiff
  # see here for color codes: http://bluesock.org/~willkg/dev/ansi.html
  def self.log(str)
    puts "[sitediff] #{str}"
  end

  def self.log_yellow(str)
    puts "\033[0;33m[sitediff] #{str}\033[00m"
  end

  def self.log_red(str)
    puts "\033[0;31m[sitediff] #{str}\033[00m"
  end

  def self.log_red_background(str)
    puts "\033[0;41m[sitediff] #{str}\033[00m"
  end

  def self.log_green_background(str)
    puts "\033[0;42;30m[sitediff] #{str}\033[00m"
  end

  def self.log_yellow_background(str)
    puts "\033[0;43;30m[sitediff] #{str}\033[00m"
  end

  def self.log_green(str)
    puts "\033[0;32m[sitediff] #{str}\033[00m"
  end
end

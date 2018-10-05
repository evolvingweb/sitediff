FROM ubuntu:14.04

ENV DEBIAN_FRONTEND noninteractive

# Minimal dependencies
# Building ruby native extensions requires ruby-dev and make
# Nokogiri requires libxml2, libxslt, pkg-config to build
# Typhoeus requires libcurl3 to run
# We need rake for our build
# Install Ruby.
RUN apt-get update
RUN apt-get install -y software-properties-common 
RUN add-apt-repository -y ppa:brightbox/ruby-ng
RUN apt-get update
RUN apt-get install -y ruby2.5 ruby2.5-dev make pkg-config libxml2-dev libxslt-dev libcurl3 bundler

# Force nokogiri gem not to compile libxml2, it takes too long
ENV NOKOGIRI_USE_SYSTEM_LIBRARIES 1

# Install thor and rspec globally so we can test the gem without bundle exec
RUN gem install thor rspec --no-rdoc --no-ri

ADD . /sitediff
WORKDIR /sitediff

# Build as a gem
RUN gem build sitediff.gemspec && gem install sitediff --no-rdoc --no-ri

# Commenting this since it should be covered by bundle now
# RUN gem install 'fileutils' -v '1.1.0'
# Build locally - skip this step since we have what we need
# RUN bundle install

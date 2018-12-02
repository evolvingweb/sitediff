FROM ubuntu:16.04
RUN apt-get update
RUN apt-get install -y python-software-properties software-properties-common

# We want a more recent ruby:
RUN apt-add-repository ppa:brightbox/ruby-ng
RUN apt-get update
ENV DEBIAN_FRONTEND noninteractive

# Minimal dependencies
# Building ruby native extensions requires ruby-dev and make
# Nokogiri requires libxml2, libxslt, pkg-config to build
# Typhoeus requires libcurl3 to run
# We need rake for our build
RUN apt-get install -y ruby2.5 ruby2.5-dev curl make pkg-config libxml2-dev libxslt-dev libcurl3 bundler

# Force nokogiri gem not to compile libxml2, it takes too long
ENV NOKOGIRI_USE_SYSTEM_LIBRARIES 1

# Install thor and rspec globally so we can test the gem without bundle exec
RUN gem install thor rspec --no-rdoc --no-ri

ADD . /sitediff
WORKDIR /sitediff

# Build as a gem
RUN gem build sitediff.gemspec && gem install sitediff --no-rdoc --no-ri

# Build locally
RUN bundle install

FROM ubuntu:14.04

RUN apt-get update
ENV DEBIAN_FRONTEND noninteractive

# Minimal dependencies
RUN apt-get install -y ruby-dev make pkg-config libxml2-dev libxslt-dev bundler

# Force nokogiri gem not to compile libxml2, it takes too long
ENV NOKOGIRI_USE_SYSTEM_LIBRARIES 1

ADD . /sitediff
WORKDIR /sitediff

# Build as a gem
RUN gem build sitediff.gemspec && gem install sitediff --no-rdoc --no-ri

# Build locally
RUN bundle install

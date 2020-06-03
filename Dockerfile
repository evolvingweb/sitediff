FROM ruby:2.7

ARG DEBIAN_FRONTEND=noninteractive

# Minimal dependencies
# ======
# Building ruby native extensions requires ruby-dev, make
# Nokogiri requires libxml2, libxslt, pkg-config
# Typhoeus requires libcurl3
# Our build requires rake
# Install editors: vim, nano.
RUN apt-get update
RUN apt-get install -y apt-utils
RUN apt-get install -y software-properties-common
RUN apt-get install -y make pkg-config libxml2-dev libxslt-dev
RUN apt-get install -y vim nano git

# Force nokogiri gem not to compile libxml2, it takes too long
ENV NOKOGIRI_USE_SYSTEM_LIBRARIES 1

# Install thor and rspec globally so we can test the gem without bundle exec
RUN gem install thor rspec --no-document
COPY . /sitediff
WORKDIR /sitediff

RUN apt-get install -y liblzma-dev
RUN gem install nokogiri -- --use-system-libraries --with-xml2-include=/usr/include/libxml2 --with-xml2-lib=/usr/lib/

# Build as a gem
RUN gem build sitediff.gemspec && gem install sitediff --no-document

# Build locally
RUN bundle install

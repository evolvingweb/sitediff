FROM ubuntu:16.04

ENV DEBIAN_FRONTEND noninteractive

# Minimal dependencies
# ======
# Building ruby native extensions requires ruby-dev, make
# Nokogiri requires libxml2, libxslt, pkg-config
# Typhoeus requires libcurl3
# Our build requires rake
# Install editors: vim, nano.
RUN apt-get update
RUN apt-get install -y software-properties-common 
#RUN add-apt-repository -y ppa:brightbox/ruby-ng
RUN apt-get update
RUN apt-get install -y ruby-full make pkg-config libxml2-dev libxslt-dev libcurl3 bundler
RUN apt-get install -y vim nano

# Force nokogiri gem not to compile libxml2, it takes too long
ENV NOKOGIRI_USE_SYSTEM_LIBRARIES 1

# Install thor and rspec globally so we can test the gem without bundle exec
RUN gem install thor rspec --no-rdoc --no-ri
COPY . /sitediff
WORKDIR /sitediff

RUN apt-get install -y build-essential patch ruby-dev zlib1g-dev liblzma-dev
RUN apt-get remove -y bundler && gem install bundler
RUN bundle config build.nokogiri --use-system-libraries --with-xml2-include=/usr/include/libxml2 --with-xml2-lib=/usr/lib/
RUN gem install nokogiri -v 1.8.2

# Build as a gem
RUN gem build sitediff.gemspec && gem install sitediff --no-rdoc --no-ri

# Build locally
RUN bundle install

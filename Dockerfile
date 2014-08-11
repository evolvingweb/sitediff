FROM ubuntu:12.04

RUN apt-get update

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get install -y build-essential curl git vim
RUN apt-get install -y libreadline6 libreadline6-dev autoconf libc6-dev ncurses-dev automake libtool bison pkg-config
RUN apt-get install -y libyaml-dev libxml2-dev libxslt-dev
RUN apt-get install -y ruby1.9.1 ruby1.9.1-dev
RUN apt-get install -y python-beautifulsoup

RUN gem install bundler

# workaround for https://github.com/dotcloud/docker/issues/2424
#  and https://github.com/progrium/buildstep/pull/38
RUN locale-gen en_US.UTF-8 && dpkg-reconfigure locales && update-locale LANG=en_US.UTF-8
ENV LANG en_US.utf8

# otherwise nokogori install is tooo slow... see https://groups.google.com/forum/#!topic/nokogiri-talk/9r4zjWMP1DA
ENV NOKOGIRI_USE_SYSTEM_LIBRARIES 1

# add these separately for docker caching
ADD Gemfile /tmp/Gemfile
ADD Gemfile.lock /tmp/Gemfile.lock
RUN cd /tmp; bundle install

ADD . /var/sitediff
WORKDIR /var/sitediff
CMD [ "/bin/bash" , "start.sh" ]

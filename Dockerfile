# DOCKER-VERSION 0.5.3
FROM ubuntu:12.10

RUN apt-get update

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get install -y build-essential curl git vim
RUN apt-get install -y libreadline6 libreadline6-dev autoconf libc6-dev ncurses-dev automake libtool bison pkg-config 
RUN apt-get install -y libyaml-dev libxml2-dev libxslt-dev 
RUN apt-get install -y ruby1.9.1
RUN gem install bundler

# workaround for https://github.com/dotcloud/docker/issues/2424
#  and https://github.com/progrium/buildstep/pull/38
RUN locale-gen en_US.UTF-8 && dpkg-reconfigure locales && update-locale LANG=en_US.UTF-8
ENV LANG en_US.utf8

# add these separately for docker caching
ADD Gemfile /tmp/Gemfile
ADD Gemfile.lock /tmp/Gemfile.lock
RUN cd /tmp; bundle install

ADD . /src
WORKDIR /src

# note that you still need to port forward the exposed port, via "docker run -p 4567:4567 ..."
EXPOSE 4567
CMD ["bundle", "exec", "ruby", "/src/webapp/app.rb", "-p", "4567", "-o", "0.0.0.0"]

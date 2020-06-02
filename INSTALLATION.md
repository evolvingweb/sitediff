# SiteDiff: Installation

The SiteDiff CLI, as the name suggests, is mostly a command-line tool powered
by Ruby. Please refer to the proper installation instructions depending on your
operating system.

## Table of contents

* [CentOS](#centos)
* [Docker](#docker)
* [MacOS](#macos)
* [Ubuntu](#ubuntu)
* [Windows](#windows)
* [Development](#development)

## CentOS

These instructions are for CentOS 7 or higher.

The default Ruby version is 2.0 but you will need Ruby 2.3 or higher for CentOS.

```bash
sudo yum update
sudo yum install centos-release-scl
sudo yum install rh-ruby23 rh-ruby23-ruby-devel
scl enable rh-ruby23 bash
```

Here are some dependencies which mostly require a manual installation.

```bash
sudo yum install libzip-devel gcc patch make
sudo yum install libxml2-devel libxslt-devel libcurl
```

We recommend installing _nokogiri_ before the SiteDiff gem. If possible,
avoid using `sudo` for `gem install`.

```bash
gem install nokogiri --no-rdoc --no-ri -- --use-system-libraries=true —with-xml2-include=/usr/include/libxml2
gem install sitediff -v '0.0.6'
```

## Docker

There is a `Dockerfile` in the root of the SiteDiff git repository. It uses
Ubuntu 18.04. Note that SiteDiff will use port `13080` for the result server.

```bash
git clone https://github.com/evolvingweb/sitediff
cd sitediff
docker build -t sitediff .
docker run -p 13080:13080 -t --detach --name sitediff sitediff
docker exec -it sitediff /bin/bash
```

## MacOS

You will need [Homebrew](https://brew.sh/) for Mac.

If your version of Ruby is not 2.3 or later, you will need to upgrade.

```bash
brew install rbenv ruby ruby-build
```

There are many dependencies, which are often already installed on many Macs.

```bash
brew install autoconf libffi libtool libyaml openssl pkg-config
```

We recommend installing _nokogiri_ before the sitediff gem. However, on most
recent Macs, the `nokogiri` step below will fail and it can be safely skipped.
If possible avoid using `sudo` for `gem install`.

```bash
gem install nokogiri --no-rdoc --no-ri -- --use-system-libraries=true —with-xml2-include=/usr/include/libxml2
gem install sitediff -v '0.0.6'
```

## Ubuntu

These instructions are for Ubuntu 16.04 or higher.

You'll need [Ruby](https://www.ruby-lang.org/) 2.3 or higher.

```bash
sudo apt-get install software-properties-common
sudo add-apt-repository -y ppa:brightbox/ruby-ng
sudo apt-get update
sudo apt-get install ruby2.3 ruby2.3-dev
sudo apt-get update
sudo apt-get upgrade
```

Here are some dependencies which mostly require a manual installation.

```bash
sudo apt-get install -y ruby-dev libz-dev gcc patch make
sudo apt-get install -y libxml2-dev libxslt-dev libcurl3
```

We recommend installing _nokogiri_ before the SiteDiff gem. If possible,
avoid using `sudo` for `gem install`.

```bash
gem install nokogiri --no-rdoc --no-ri -- --use-system-libraries=true --with-xml2-include=/usr/include/libxml2
gem install sitediff
```

## Windows

SiteDiff doesn't officially support the Windows operating system. However, you
should be able to use SiteDiff inside a VM or a Docker container on Windows.

---

## Development

You will need the same dependencies installed as required for the gem.
Depending on what you use for development, please see instructions for
CentOS, MacOS, Ubuntu above.

Install `bundler` on your system.

```bash
gem install bundle
```

There is an up-to-date configuration file for bundle which you can use.

```bash
git clone https://github.com/evolvingweb/sitediff
cd sitediff
git checkout dev
bundle install
```

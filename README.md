# SiteDiff

SiteDiff makes it easy to see differences between the local and remote versions of a website.
Tool to render an HTML page displaying a diff between corresponding pages on two almost-identical websites.
Useful for QAing re-deployments, site upgrades, etc.


Here's how to invoke sitediff from the command line, and the resulting HTML:
```
bundle exec ruby bin/sitediff diff http://www.mcgill.ca/study/2013-2014/faculties/continuing/graduate/programs/diploma-management-%E2%80%94-treasury-%E2%80%94-finance-concentration 
```
![ScreenShot of SiteDiff Output](https://dl.dropbox.com/u/29440342/screenshots/OGGNTONZ-2014.01.08-13-39-08.png)

## Installation

```
# clone the code
git clone https://github.com/dergachev/sitediff.git
cd sitediff

Before using the app, you need to create `config.yaml`, as follows:

```
cp config.yaml.example config.yaml
vim config.yaml  # modify as necessary
```

For now, it just specifies your dev and prod domains.
Here's config.yaml.example:

```
sites:
  dev: 
    url: http://mydevsite.com
    auth_basic:
      user: devuser
      password: devpass
  prod: 
    url: http://myprodsite.com
```

To run the app locally, do the following:

```
bundle install --path vendor/bundle
bundle exec ruby webapp/app.rb -o 0.0.0.0 -p 4567
```

To run it in a docker container, build and run it as follows:

```
docker build -t <yourusername>/sitediff .
docker run -p 4567:4567 <yourusername>/sitediff
```

In either case, the following should now: http://localhost:4567/diff?url=http://www.mcgill.ca/study/2013-2014/

## Bookmarklet

TODO: create bookmarklet for sitediff. Along the lines of https://gist.github.com/dergachev/8291018

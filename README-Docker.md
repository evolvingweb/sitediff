# Running sitediff under Docker

Using Docker to run sitediff can be easier than getting the appropriate environment set up, with the right versions of Ruby etc, on your machine.

There are two Dockerfiles here: one is based on Ubuntu and one on Alpine Linux, which is quicker to build and produces much smaller container images.

Suppose you decide to use the Alpine one.  Build a container with 

    docker build -t sitediff -f Dockerfile-alpine .

then you can run it, at its most basic, with:

    docker run sitediff

However, in reality, you probably want it to be able to output some files into, say, the current directory, so you could mount that in the container as /sitediff using a `-v` option. 

And you want to see output as it is produced, in pretty colours, so you might tell it you have a more intereactive terminal using a `-it` option.

So your typical first command might look more like:

    docker run -it -v `pwd`:/sitediff sitediff init http://mysite.com

If you wish to make use of sitediff's ability to serve up its own web pages with the 'serve' command, you'll also need to enable access to the port it uses to do that, normally 13080, e.g.

    docker run -it -v `pwd`:/sitediff -p 13080:13080 sitediff serve

and then connect to http://localhost:13080.

Lastly, if the website you want to compare is running on your Docker host machine, 
as it may well be during development, then remember you can use the special hostname
'host.docker.internal' to refer to the host from within a container.

So, imagine you want to compare the public site http://mysite.com to the version running on port 80 on your laptop. You might do something like this:

    # Create a local configuration and cache of the public site
    # in the mysite directory, with the local copy as the 'after' version:

    docker run -it -p 13080:13080 -v `pwd`/mysite:/sitediff \
        sitediff init \
        http://mysite.com \
        http://host.docker.internal

    # Now compare the two, but use the original URLs in the report:
    docker run -it -v `pwd`/mysite:/sitediff sitediff diff \
        --after-url-report=http://localhost

    # Now serve up comparison on localhost:13080
    docker run -it -v `pwd`/mysite:/sitediff sitediff serve

*Quentin Stafford-Fraser, Dec 2018*

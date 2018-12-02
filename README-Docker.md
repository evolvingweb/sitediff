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

    docker run -it -v `pwd`:/sitediff sitediff http://mysite.com

If you wish to make use of sitediff's ability to serve up its own web pages with the 'serve' command, you'll also need to enable access to the port it uses to do that, normally 13080, e.g.

    docker run -it -v `pwd`:/sitediff -p 13080:13080 sitediff serve

and then connect to http://localhost:13080.

*Quentin Stafford-Fraser, Dec 2018*

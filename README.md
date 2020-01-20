# SiteDiff

**Note:** Please note that version 1.0.0 introduces some backwards incompatible
changes.

[![Build Status](https://travis-ci.org/evolvingweb/sitediff.svg?branch=master)](https://travis-ci.org/evolvingweb/sitediff)

SiteDiff makes it easy to see how a website changes. It can compare two similar
sites or it can show how a single site changed over time. It helps identify
undesirable changes to the site's HTML and it's a useful tool for conducting QA
on re-deployments, site upgrades, and more! 

Each time you run SiteDiff, it produces an HTML report showing whether pages on
your site have changed or not. For changed paths, you can see a colorized diff
of the changes, or compare the visual differences side-by-side in a browser.

SiteDiff supports a range of normalization / sanitization rules. These allow
you to eliminate spurious differences, narrowing down differences to the ones
that materially affect the site.

## Table of contents

- [Introduction](#sitediff)
- [Installation](#installation)
  - [Ubuntu](#ubuntu)
  - [CentOS](#centos)
  - [MacOS](#macos)
  - [Docker](#docker)
  - [Dev Environment Setup](#dev) 
- [Demo](#demo)
- [User's guide](#users-guide)
  - [Getting started](#getting-started)
  - [Comparing multiple sites](#comparing-multiple-sites)
  - [Preventing spurious diffs](#preventing-spurious-diffs)
  - [Getting help](#getting-help)
  - [Tips & tricks](#tips--tricks)
  - [Configuration](#configuration)


## Installation

### Ubuntu 16.04 or 18.04

You'll need [Ruby](https://www.ruby-lang.org/) 2.3 or higher. 

```bash
sudo apt-get install software-properties-common
sudo add-apt-repository -y ppa:brightbox/ruby-ng
sudo apt-get update
sudo apt-get install ruby2.3 ruby2.3-dev
sudo apt-get update
sudo apt-get upgrade
```

Dependencies which in mostly require a manual installation.

```bash
sudo apt-get install -y ruby-dev libz-dev gcc patch make
sudo apt-get install -y libxml2-dev libxslt-dev libcurl3
```

We recommend installing _nokogiri_ before the sitediff gem. If possible
try to avoid using sudo for gem install.

```bash
gem install nokogiri --no-rdoc --no-ri -- --use-system-libraries=true --with-xml2-include=/usr/include/libxml2
gem install sitediff
```

### CentOS 7 instructions

The default Ruby version is 2.0 but you will need Ruby 2.3 or higher for CentOS.

```bash
sudo yum update
sudo yum install centos-release-scl
sudo yum install rh-ruby23 rh-ruby23-ruby-devel
scl enable rh-ruby23 bash
```
 
Various dependencies which in most cases require a manual install.

```bash
sudo yum install libzip-devel gcc patch make
sudo yum install libxml2-devel libxslt-devel libcurl
```
 
We recommend installing _nokogiri_ before the sitediff gem. If possible
try to avoid using sudo for gem install.

```bash
gem install nokogiri --no-rdoc --no-ri -- --use-system-libraries=true —with-xml2-include=/usr/include/libxml2
gem install sitediff -v '0.0.6'
```

### MacOS instructions

You will need [Homebrew](https://brew.sh/) for Mac.

If your version of Ruby is not 2.3 or later, you will need to upgrade.

```bash
brew install rbenv ruby ruby-build
```

There are many dependencies, which are often already installed on many Macs.

```bash
brew install autoconf libffi libtool libyaml openssl pkg-config
```

While we recommend installing _nokogiri_ before the sitediff gem, on most
recent Macs, the nokogiri step below will fail and it can be safely skipped.
If possible avoid using sudo for gem install.

```bash
gem install nokogiri --no-rdoc --no-ri -- --use-system-libraries=true —with-xml2-include=/usr/include/libxml2
gem install sitediff -v '0.0.6'
```

### Docker instructions

There is an up-to-date Dockerfile you can use in the git repo. It uses Ubuntu
16.04. Note that Sitediff will use 13080 to display the result server.

```bash
git clone https://github.com/evolvingweb/sitediff
cd sitediff
docker build -t sitediff-u16 .
docker run -p 13080:13080 -t --detach --name sitediff sitediff-u16
docker exec -it sitediff /bin/bash
```

### Dev environment setup

You will need the same dependencies installed as required for the gem.
Depending on what you use for development, please see instructions for
CentOS, MacOS, Ubuntu above.

Install Bundler on your system. 

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

## Demo

You must have installed all dependencies for your environment, and the
bundle gem. To quickly see what SiteDiff can do:

```sh
git clone https://github.com/evolvingweb/sitediff
cd sitediff
bundle install
bundle exec thor fixture:serve
```

Then visit http://localhost:13080 to view the report.

Here is an example SiteDiff report:
![page report preview](misc/sitediff%20-%20overview%20report.png?raw=true)

And here is an example SiteDiff diff of a specific path:
![page report preview](misc/sitediff%20-%20page%20report.png?raw=true)

## User's guide

### Getting started

To use SiteDiff on your site, create a configuration for your site:

```sitediff init http://mysite.example.com```

SiteDiff will generate a configuration file (named `sitediff.yaml` by default).
By default, it will also crawl your site, finding pages and caching their
contents. A list of discovered paths will be saved to a `paths.txt` file.

You can open the configuration file ```sitediff/sitediff.yaml``` to see what
SiteDiff found. See [the configuration reference](#configuration) for details
on the contents of that file, and how you might want to alter it.

Now, you can make alterations to your site. For example, try upgrading a
framework that your site uses. After you're done, check what actually changed:

```sitediff diff```

For each page, SiteDiff will report whether it did or did not change. For pages
that changed, it will display a diff. If you want a nicer view of the changes,
run SiteDiff's web report:

```sitediff serve```

SiteDiff will start an internal web server and open a report page on your
browser. For each page, you can see the diff and a side-by-side view of the
old and new versions.

You can now see if the changes were as you expected, or if some things didn't
quite work out as you hoped. If you noticed unexpected changes, congratulations:
SiteDiff just helped you find an issue you would have missed otherwise!

---

As you fix any issues, you can continue to alter your site and run
```sitediff diff``` to check the changes against the old version. Once you're
satisfied with the state of your site, you can inform SiteDiff that it should
re-cache your site:

```sitediff store```

The next time you run ``sitediff diff``, it will use this new version as the
reference for comparison.

Happy diffing!

### Comparing 2 sites

Sometimes you have two sites that you want to compare, for example a production
site hosted on a public server and a development site hosted on your computer.
SiteDiff can handle this situation, too! Just inform SiteDiff that there are
two sites to compare:

```sitediff init http://mysite.example.com http://localhost/mysite```

Then when you run `sitediff diff`, it will compare the cached version of the
first site with the current version of the second site.

If both the first and second sites may be changing, you should tell SiteDiff
not to cache either site:

```sitediff diff --cached=none```

### Preventing spurious diffs

Sometimes sites have spurious differences, that you don't want to show up in a
comparison. For example, many sites protect against Cross-Site Request Forgery
using a [semi-random token](http://en.wikipedia.org/wiki/Cross-site_request_forgery#Synchronizer_token_pattern).
Since this token changes on each HTTP GET, you probably don't care about such
a change.

To help with issues such as this, SiteDiff allows you to normalize the HTML it
fetches as it compares pages. In the ```sitediff.yaml``` configuration file,
you can add "sanitization rules", which specify either DOM transformations or
regular expression substitutions.

Here's an example of a rule you might add to remove CSRF-protection tokens
generated by Django:

```yaml
dom_transform:
  - title: Remove CSRF tokens
    type: remove
    selector: input[name=csrfmiddlewaretoken]
```

When you run ```sitediff init```, SiteDiff will even auto-detect some
potentially useful rules, and include them in your configuration file. They
start disabled, but you can easily remove the ```disabled: true``` line to try
them out. Currently only rules useful for common Drupal sites are auto-detected.

See the [configuration file reference](#configuration) for more details.

### Getting help

SiteDiff has built-in help! To see a list of commands:

```sitediff help```

To get help on the options for a particular command, eg: ```diff```:

```sitediff help diff```

### Tips & tricks

* **Finding configuration files**

  By default SiteDiff will put everything in the `sitediff` folder. You can use
  the `--directory` flag to specify a different directory.

  ```sitediff init -C my_project_folder https://example.com
  sitediff diff -C my_project_folder
  sitediff serve -C my_project_folder```

* **Handling large configuration files**

  If your configuration file starts getting really big, SiteDiff lets you
  separate it out into multiple files. Just have one base file that includes
  other files:

  ```yaml
  includes:
    - sanitization.yaml
    - paths.yaml
  ```

  This allows you to separate your configuration into logical groups.
  For example, generic rules for your site could live in a `generic.yaml` file,
  while rules pertaining to a particular update you're conducting could
  live in `update-8.2.yaml`.

* **Specifying paths**

  When you run ```sitediff diff```, you can specify which pages to look at in
  2 ways:

  1. The option ```--paths /foo /bar ...```.

     If you're trying to fix one page in particular, specifying just that one
     path will make ```sitediff diff``` run quickly!

  1. The option ```--paths-file FILE``` with a newline-delimited text file.

     This is particularly useful when you're trying to eliminate all diffs.
     SiteDiff creates a file ```output/failures.txt``` containing all paths
     which had differences, so as you try to fix differences, you can run:

     ```sitediff diff --paths-file sitediff/failures.txt```

* **Debugging rules**

  When a sanitization rule isn't working quite right for you, you might run
  `sitediff diff` many times over. If fetching all the pages is taking too long,
  try adding the option ```--cached=all```. This tells SiteDiff not to re-fetch
  the content, but just compare previously cached versions — it's a lot faster!

* **Handling security**

  Often development or staging sites are protected by [HTTP Authentication](http://en.wikipedia.org/wiki/Basic_access_authentication).
  SiteDiff allows you to specify a username and password, by using a URL like
  `http://user:pass@example.com`.
  
  There is also an option to ignore untrusted certificates by using the
  `--insecure` flag.

* **Running inside containers**

  If you run SiteDiff inside a container or virtual machine, the URLs in its
  report might not work from your host, such as ```localhost```. You can fix
  this by using the ```--before-url-report``` and ```--after-url-report```
  options, to tell SiteDiff to use a different URL in the report than the one
  it uses for fetching.

  For example, if you ran `sitediff init http://mysite.com http://localhost`
  inside a [Vagrant](https://www.vagrantup.com/) VM, you might then run
  something like:

  ```sitediff diff --after-url-report=http://vagrant:8080```

* **Curl options**

  [Many options](https://curl.haxx.se/libcurl/c/curl_easy_setopt.html) can be
  passed to the underlying curl library. Add `--curl_options=name1:value1 name2:value2`
  to the command line (such as `--curl_options=max_recv_speed_large:100000`
  (remove the `CURLOPT_` prefix and write the name in lowercase) or add them to
  your configuration file.

  ```yaml
  settings:
    curl_opts:
      max_recv_speed_large: 10000
      ssl_verifypeer: false
  ```

  These CURL options can be put under the `settings` section of `sitediff.yaml`
  as demonstrated above.

* **Throttling**

  A few options are also available to control how aggressively SiteDiff crawls.

     - There's a command line option `--concurrency=N` for `sitediff init`
     which controls the maximum number of simultaneous connections made.
     Lower N mean less aggressive. The default is 3. You can specify this in the
     `sitediff.yaml` file under the `settings` key.

     - The underlying curl library has [many options](https://curl.haxx.se/libcurl/c/curl_easy_setopt.html)
     such as `max_recv_speed_large` which can be helpful.
     - There is a special command line option `--interval=T` for
     `sitediff init`. This option and allows the fetcher to delay for
     T milliseconds between fetching pages. You can specify this in the
     `sitediff.yaml` file under the `settings` key.
 
* **Timeouts**

  By default, no timeout is set but one can be added `--curl_options=timeout:60`
  or in your configuration file.

  ```yaml
  settings:
    curl_opts:
      timeout: 60 # In seconds; or...
      timeout_ms: 60000 # In milliseconds.
  ```

* **Whitelisting and Blacklisting**

By default sitediff crawls pages that are indicated with an HTML anchor using
the `<A HREF` syntax. Most pages linked will be HTML pages, but some links
will contain binaries such as PDF documents and images.

Using the option `--blacklist='.*\.pdf'` ensures the crawler skips links
for document with a `.pdf` extension. Note that the regular expression is
applied to the path of the URL, not the base of the URL.

For example `--blacklist='.*\.com'` will not match `http://www.google.com/`,
because the path of that URL is `/` while the base is `www.google.com`.      

## Configuration

SiteDiff relies on a [YAML](http://yaml.org/) configuration file, usually
called ```sitediff.yaml```. You can create a reasonable one using
`sitediff init`, but there are many useful things you may want to add or change
manually.

The following ```sitediff.yaml``` keys are recognized by SiteDiff:

* **before_url** and **after_url**: The two base URLs to compare, for example:

  ```yaml
  before_url: http://example.com/subsite
  after_url: http://localhost:8080/subsite
  ```

  They can also be paths to directories on the local filesystem.

  The _after_url_ MUST provided either at the command-line or in the
  `sitediff.yaml`. If the _before_url_ is provided, SiteDiff will compare the
  two sites. Otherwise, it will compare the current version of the `after` site
  with the stored version of that site, as created by `sitediff init` or
  `sitediff store`.

* **paths**: The list of paths to check, rooted at the base URL. For example:

  ```yaml
  paths:
    - index.html
    - page.html
    - cgi-bin/test.cgi?param=value
  ```

  In the example above, SiteDiff would compare _`http://example.com/subsite/index.html`_
  and _`http://localhost:8080/subsite/index.html`_, followed by _page.html_,
  and so on.

  The _paths_ MUST be provided either at the command-line or in the
  `sitediff.yaml` file.

* **selector**: Chooses the sections of HTML we wish to compare, if you don't
  want to compare the entire page. For example if you want to only compare
  breadcrumbs between your two sites, you might specify:

  ```yaml
  selector: '#breadcrumb'
  ```

* **before_url_report** and **after_url_report**: Changes how SiteDiff reports
  which URLs it is comparing, but don't change what it actually compares.

  Suppose you are serving your 'after' website on a virtual machine with
  IP 192.1.2.3, and you are also running SiteDiff inside that VM. To make links
  in the report accessible from outside the VM, you might provide

  ```yaml
  after_url: http://localhost
  after_url_report: http://192.1.2.3
  ```

* **sanitization**: A list of regular expression rules to normalize your HTML for comparison.

  Each rule should have a **pattern** regex, which is used to search the HTML.
  Each found instance is replaced with the provided **substitute** or deleted
  if no substitute is provided.  A rule may also have a **selector**, which
  constrains it to operate only on HTML fragments which match that CSS selector.

  For example, forms on Drupal sites have a randomly generated `form_build_id`
  on form pages:

  ```html
  <input type="hidden" name="form_build_id" value="form-1cac6b5b6141a72b2382928249605fb1"/>
  ```

  We're not interested in comparing random content, so we could use the
  following rule to fix this:

  ```yaml
    sanitization:
    # Remove form build IDs
    - pattern: '<input type="hidden" name="form_build_id" value="form-[a-zA-Z0-9_-]+" *\/?>'
      selector: 'input'
      substitute: '<input type="hidden" name="form_build_id" value="__form_build_id__">'
   ```

  Sanitization rules may also have a **path** attribute, whose value is a
  regular expression. If present, the rule will only apply to matching paths.

* **dom_transform**: A list of transformations to apply to the HTML before comparing.

  This is similar to _sanitization_, but it applies transformations to the
  structure of the HTML, instead of to the text. Each transformation has a
  **type**, and potentially other attributes. The following types are available:

  * **remove**: Given a **selector**, removes all elements that match it.

  For example, say we have a block containing the current time, which is
  expected to change. To ignore that, we might choose to delete the block
  before comparison:

  ```yaml
    dom_transform:
    # Remove current time block
    - type: remove
    - selector: div#block-time
  ```

  * **unwrap**: Given a **selector**, replaces all matching elements with
  their children. For example, your content on one side of the comparison might
  look like this:

    ```html
    <p>This is some text</p>
    <img src="test.png"/>
    ```

	But on the other side, it might be wrapped in an `article` tag:
    ```html
    <article>
      <p>This is some text</p>
      <img src="test.png"/>
    </article>
    ```

    You could fix it with the following configuration:

    ```yaml
    dom_transform:
      - type: unwrap
        selector: article
    ```

  * **remove_class**: Given a **selector** and a **class**, removes that class
  from each element that matches the selector. It can also take a list of
  classes, instead of just one.

  For example, here are two sample rules for removing a single class and
  removing multiple classes from all `div` elements:

  ```yaml
  dom_transform:
    # Remove class foo from div elements
    - type: remove_class
      selector: div
      class: class-foo
    # Remove class bar and class baz from div elements
    - type: remove_class
      selector: div
      class:
        - class-bar
        - class-baz
  ```

  * **unwrap_root**: Replaces the entire root element with its children.

* **before** and **after**: Applies rules to just one side of the comparison.

  These blocks can contain any of the following sections: _selector_,
  _sanitization_,  _dom_transform_. Such a section placed in _before_ will be
  applied just to the _before_ side of the comparison and similarly for _after_.

  For example, if you wanted to let different date formatting not create diff
  failures, you might use the following:

  ```yaml
  before:
    sanitization:
    - pattern: '[1-2][0-9]{3}/[0-1][0-9]/[0-9]{2}'
      substitute: '__date__'
  after:
    sanitization:
    - pattern:  '[A-Z][a-z]{2} [0-9]{1,2}(st|nd|rd|th) [1-2][0-9]{3}'
      substitute: '__date__'
  ```

   The above rule will replace dates of the form `2004/12/05` in _before_ and
   dates of the form `May 12th 2004` in _after_ with `__date__`.

* **includes**: The names of other configuration YAML files to merge with
  this one.

  ```yaml
  includes:
    - config/sanitize_domains.yaml
    - config/strip_css_js.yaml
  ```

* **settings**: This contains various parameters which affect the way SiteDiff
  works. You can have the following keys under `settings`.

  * **interval**: An integer indicating the number of milliseconds SiteDiff
    should wait for between requests.

  * **concurrency**: The maximum number of simultaneous requests that SiteDiff
    should make.

  * **blacklist**: A RegEx indicating the paths that should not be crawled.

  * **whitelist**: A RegEx indicating the paths that should be crawled.

  * **depth**:: The depth to which SiteDiff should crawl the website. Defaults
    to 3, which means, 3 levels deep.

  * **curl_opts**: Options to pass to the underlying curl library. Remove the
    `CURLOPT_` prefix in this [full list of options](https://curl.haxx.se/libcurl/c/curl_easy_setopt.html)
    and write in lowercase. Useful for throttling.

    ```yaml
    curl_opts:
      connecttimeout: 3
      followlocation: true
      max_recv_speed_large: 10000
    ```

### Samples

The `config` directory contains some example ```sitediff.yaml``` files.
For example, [sitediff.example.yaml](config/sitediff.example.yaml).

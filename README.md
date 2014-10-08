# SiteDiff

[![Build Status](https://travis-ci.org/evolvingweb/sitediff.svg?branch=master)](https://travis-ci.org/evolvingweb/sitediff)
[![CircleCI Status](https://circleci.com/gh/evolvingweb/sitediff/tree/master.png?style=shield)](https://circleci.com/gh/evolvingweb/sitediff)

SiteDiff makes it easy to see differences between two versions of a website. It
accepts a set of paths to compare two versions of the site together with
potential normalization/sanitization rules. From the provided paths and
configuration SiteDiff generates an HTML report of all the status of HTML
comparison between the given paths together with a readable diff-like HTML for
each specified path containing the differences between the two versions of the
site. It is useful tool for QAing re-deployments, site upgrades, etc.

## Demo

To quickly see what sitediff can do:

```sh
git clone https://github.com/evolvingweb/sitediff
cd sitediff
bundle install
bundle exec rake fixture:serve
```

Then visit http://localhost:13080/report.html to view the report.

Here is an example SiteDiff report:
![](https://dl.dropboxusercontent.com/u/6215598/Screenshot%20from%202014-04-10%2014%3A41%3A46.png)

And here is an example SiteDiff diff report of a specific path:
![](https://dl.dropboxusercontent.com/u/6215598/Screenshot%20from%202014-04-10%2013%3A54%3A26.png)

## Installation

```gem install sitediff```

## Usage

SiteDiff relies on a YAML configuration file to pick up the paths and required
sanitization rules. Once you have created your _config.yml_, you can run SiteDiff like so:

```sh
sitediff diff config.yml
```

The following config.yml configuration blocks are recognized by SiteDiff:

* **before_url** and **after_url**: The two base URLs to compare, for example:

  ```yaml
  before_url: http://example.com/subsite
  after_url: http://localhost:8080/subsite
  ```

  They can also be paths to directories on the local filesystem.

  Both _before_url_ and _after_url_ MUST provided either at the command-line or in the config.yml.

* **paths**: The list of paths to check, rooted at the base URL. For example:

  ```yaml
  paths:
    - index.html
    - page.html
    - cgi-bin/test.cgi?param=value
  ```

  In the example above, SiteDiff would compare _`http://example.com/subsite/index.html`_ and _`http://localhost:8080/subsite/index.html`_, followed by _page.html_, and so on.

  The _paths_ MUST provided either at the command-line or in the config.yml.

* **selector**: Chooses the sections of HTML we wish to compare, if you don't want to compare the entire page. For example if you want to only compare breadcrumbs between your two sites, you might specify:

  ```yaml
  selector: '#breadcrumb'
  ```

* **before_url_report** and **after_url_report**: Changes how SiteDiff reports which URLs it is comparing, but don't change what it actually compares.

  Suppose you are serving your 'after' website on a virtual machine with IP 192.1.2.3, and you are also running SiteDiff inside that VM. To make links in the report accessible from outside the VM, you might provide

  ```yaml
  after_url: http://localhost
  after_url_report: http://192.1.2.3
  ```

* **sanitization**: A list of regular expression rules to normalize your HTML for comparison.

  Each rule should have a **pattern** regex, which is used to search the HTML. Each found instance is replaced with the provided **substitute**, or deleted if no substitute is provided.  A rule may also have a **selector**, which constrains it to operate only on HTML fragments which match that CSS selector.

  For example, forms on Drupal sites have a build_id which is randomly generated:

  ```html
  <input type="hidden" name="form_build_id" value="form-1cac6b5b6141a72b2382928249605fb1"/>
  ```

  We're not interested in comparing random content, so we could use the following rule to fix this:

  ```yaml
    sanitization:
    # Remove form build IDs
    - pattern: '<input type="hidden" name="form_build_id" value="form-[a-zA-Z0-9_-]+" *\/?>'
      selector: 'input'
      substitute: '<input type="hidden" name="form_build_id" value="__form_build_id__">'
   ```

* **dom_transform**: A list of transformations to apply to the HTML before comparing.

  This is similar to _sanitization_, but it applies transformations to the structure of the HTML, instead of to the text. Each transformation has a **type**, and potentially other attributes. The following types are available:

  * **remove**: Given a **selector**, removes all elements that match it.

  * **unwrap**: Given a **selector**, replaces all elements that match it with their children. For example, your content on one side of the comparison might look like this:

    ```html
    <p>This is some text</p>
    <img src="test.png"/>
    ```

	But on the other side, it might be wrapped in an article tag:
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

  * **remove_class**: Given a **selector** and a **class**, removes that class from each element that matches the selector. It can also take a list of classes, instead of just one.

  * **unwrap_root**: Replaces the entire root element with its children.

* **before** and **after**: Applies rules to just one side of the comparison.

  These blocks can contain any of the following sections: _selector_, _sanitization_,  _dom_transform_. Such a section placed in _before_ will be applied just to the _before_ side of the comparison, and similarly for _after_.

  For example, if you wanted to let different date formatting not create diff failures, you might use the following:

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

   which will replace dates of the form `2004/12/05` in _before_ and dates of
   the form `May 12th 2004` in _after_ with `__date__`.

* **include**: The names of other configuration YAML files to merge with this one.

  ```yaml
  includes:
    - config/sanitize_domains.yaml
    - config/strip_css_js.yaml
  ```

## Samples

The config directory contains some example config.yml files. Eg: [config.yaml.example](config/config.yaml.example)

## Options

The following command-line options are available for sitediff:

* **--before=URL**
* **--after=URL**

  The base URLs to compare. Overrides _before_url__ or _after_url_ in the config.yml.


* **--before-url-report=URL**
* **--after-url-report=URL**

  Change how SiteDiff reports the before/after URLs. Overrides _before_url_report_ or _after_url_report_ in the config.yml.


* **--paths=FILE**: A file which contains a list of paths to compare, separated by newlines. Overrides _path_ in the config.yml.


* **--dump-dir=DIR**: Where to place the output report and associated files. Defaults to `output` in the working directory.


* **--paths-from-failures**: Uses as _paths_ only the paths that failed in the last run of SiteDiff.


* **--cache=FILE**: Caches HTTP requests and responses in the given file. This can help for sites that are slow, if you're performing multiple runs of SiteDiff.

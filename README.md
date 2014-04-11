# SiteDiff

SiteDiff makes it easy to see differences between two versions of a website. It
accepts a set of paths to compare two versions of the site together with
potential normalization/sanitization rules. From the provided paths and
configuration SiteDiff generates an HTML report of all the status of HTML
comparison between the given paths together with a readable diff-like HTML for
each specified path containing the differences between the two versions of the
site. It is useful tool for QAing re-deployments, site upgrades, etc.

## Demo

To quickly see what sitediff can do, follow these steps to get sitediff to
compare two sets of static HTMLs served by a simple HTTP server:

```bash
cd spec/fixtures/before && python -m SimpleHTTPServer 8801
# Serving HTTP on 0.0.0.0 port 8801 ...

# in a separate session
cd spec/fixtures/after && python -m SimpleHTTPServer 8802
# Serving HTTP on 0.0.0.0 port 8802 ...

# in a third session
bundle exec bin/sitediff diff --before-url=http://localhost:8801 --after-url=http://localhost:8802 spec/fixtures/config.yaml
```

Or if you have docker installed you can simply:

```bash
make build_sitediff # creates a docker image containing the sitediff executable
make start_fixtures # starts two fixture containers serving the same HTML content as above
make sitediff_fixtures # perform the diff, generate a report
make sitediff_serve # serve the reports and diff files so we can browse them
```

Here is an example SiteDiff report:
![](https://dl.dropboxusercontent.com/u/6215598/Screenshot%20from%202014-04-10%2014%3A41%3A46.png)

And here is an example SiteDiff diff report of a specific path:
![](https://dl.dropboxusercontent.com/u/6215598/Screenshot%20from%202014-04-10%2013%3A54%3A26.png)

## Usage

SiteDiff relies on a YAML configuration file to pick up the paths and required
sanitization rules. The following configuration blocks are recognized by
SiteDiff:

1. `sanitization`: a sanitization block contains a `title`, a `pattern` which is
   a regular expression in string form, and an optional `substitute` defaulting
   to empty string:

        sanitization:
        - title: 'remove form build id'
          pattern:    '<input type="hidden" name="form_build_id" value="form-[a-zA-Z0-9_-]+" *\/?>'
          substitute: '<input type="hidden" name="form_build_id" value="__form_build_id__">'

   Sanitization blocks are typically useful to avoid false positives that are in
   the form of individual strings (not hierarchical information, see
   `dom_transform`).

1. `selector`: defines the specific HTML elements we wish to compare. For
   example if you want to only compare breadcrumbs between `before` and `after`,
   you might specify:

        selector: '#breadcrumb'

   if that is how your HTML is structured.
1. `dom_transform`: Allows you to edit the DOM tree before diff-ing. This is
   again useful to allow for expected structural differences to pass through
   without causing failed comparison tests. A `dom_transform` block requires a
   `type` which specifies what kind of DOM transformation to perform, and a
   `selector` which specifies the element on which the action will be
   performed. Allowed `type` values are the following:
   1. `remove`: removes the entire element specified by the `selector` from the HTML,
   1. `unwrap`: replaces the element with its constituents. For example:

            dom_transform:
              - type: 'unwrap'
              - selector: '#123'

      will transform the following:

          <div id="#123">
            <p> Hello </p>
            <p> World </p>
          </div>

      into:

          <p> Hello </p>
          <p> World </p>

1. `before` and `after`: these two are the special blocks that can wrap any of
   the blocks above to indicate that the normalization rules defined in the
   block should only apply to either the `before` or the `after` version of the
   site. If a configuration block is found in the top level, and not under
   `before` or `after`, it will apply to both. For example, if you wanted to let
   different date formatting not create diff failures, you might use the
   following:

        before:
          sanitization:
            - title: 'remove dates'
              pattern: '[1-2][0-9]{3}/[0-1][0-9]/[0-9]{2}'
              substitute: '__date__'
        after:
          sanitization:
            - title: 'remove dates'
              pattern:  '[A-Z][a-z]{2} [0-9]{1,2}(st|nd|rd|th) [1-2][0-9]{3}'
              substitute: '__date__'


   which will replace dates of the form `2004/12/05` in `before` and dates of
   the form `May 12th 2004` in `after` with `__date__`.
1. `include`: A configuration file can reference other YAML files to pull in the
   sanitization rules and/or dom transforms defined by the external file:

        includes:
          - config/sanitize_domains.yaml
          - config/strip_css_js.yaml


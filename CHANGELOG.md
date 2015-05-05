SiteDiff Changelog
===================

## [0.0.2](https://github.com/evolvingweb/sitediff/compare/v0.0.2...v0.0.1) (May 5, 2015)

SUMMARY:

- init 
  - new subcommand!
  - crawl sites
  - auto rule generation
- CLI
  - automatically finding sitediff.yaml
  - proper exit codes
  - quiet diff
- server
  - side-by-side
  - serve cached pages
  - auto-open browser
- single-site mode
- per-path rules
- code and docs cleanup

FEATURES:

- 74ce221 Detailed installation instructions
- 127c776 Make sitediff init more robust
- 9abcfc3 show absolute paths to the user everywhere
- 3ae25ab Update README; remember config file is now sitediff.yaml
- 7d4cf75 Print full path for config missing exception
- 40dd18a Print full path for init
- f819cd2 sitediff diff: report absolute path of failures file
- 87dd419 fix broken link
- 1a51998 Start on ToC
- e798cf1 Write a user guide
- 9218863 Don't close non-existent DBM
- f00105d Rewrite intro to sitediff
- 5bb8b4b Show URL even if cached
- 34eb97b For side-by-side, use the cached version(s) if appropriate
- d16af93 Don't let someone try single-site unless they have the right caches
- 8be342e Make report say whether things are cached
- 1f91792 Rearrange columns
- b712ac3 Make the root path useful
- dd07d4b Side-by-side view
- ee2ef7a Minor reporting cleanup
- ba80234 No more spurious cache files
- ef80a6b Split out ResultServer
- 7868bcd Pass config to server
- 19d98e9 Replace URI with Addressable::URI
- 18c7717 Rationalize includes
- fa12bf1 Serve cached files
- 6092631 Better encoding fix
- cfc0905 Allow selecting whether to open in browser
- 577cf6b Fix string case
- aac3c42 Support multiple rules, only one can match
- 5f3e5ad Print results in order
- b81a94a Fix multi-selector behaviour
- b19648c Typo fix
- 7228a63 Put back validate, I removed it accidentally
- f9c0d02 Path-specific rules!
- f9f0164 Remove last vestiges of old sanitize
- 88abcdf Refactor regexps
- e2035bc Tighten up comments
- 34e165b Factor out dom transforms
- 1e2b1bb Start refactoring sanitizations
- 578789f Refactor webserver; open in browser
- 21f9724 Don't spuriously open a cache
- 6186f17 No more utils
- 94091e5 Fix cache key issue
- 62b038d Abstract out complex parts of link handling
- ddbac22 Fix Drupal.settings rule to work in both cases
- 1863f5f Close cache when done
- 9efb47d update spec with new exit codes: only fail test if exit code != 2
- 0574967 fix sanitization rule for Drupal.settings
- 7577298 strip view DOM ids
- d2e2185 exit with non-zero code if diffs are nonzero
- 5e646d1 introduce "diff --quiet": don't log actual diffs
- 9c0445f add more logging modes, make usage consistent
- 4ac4336 Lower indent, we have tons of classes here
- fad3e75 use SiteDiff.log for showing crawl errors
- f3a091f Make output similar
- 6775df6 Better output; more robust init
- 5eb8b2a escape crawled URLs
- 269b2ef Yield a failure on cache miss, instead of dying
- 58b51fe Remove extra require
- 2cd906a Prettify as part of perform_regexps; fixes #10999
- 9c8eb94 add domain sanitization to drupal.yaml
- 4f945fb skip invalid URLs while crawling + log to user while fetching
- 8fde3cd In single-site mode, apply rules globally
- f288624 Don't apply disabled rules
- 7fc2684 Allow disabling rules
- 319b701 Put things in cache the same way we get them
- 4cd6cda Only parse once
- 8ed7f7e Better path canonicalization
- d92d02f Integrate with async rules
- d785411 sitediff init: match candidate rules to before and after separately
- 9beff00 Make init more async; add caching
- a73a8e6 Pre-check if we have all the cached items we need
- f97cab9 Make all our exceptions come from SiteDiffException
- 025c8ea Allow specifying a list of paths at the command-line
- dd0cff8 don't search if dir given
- 14988f2 Create a gitignore in init
- 9313220 remove stale lib/rules/drupal.rb, clean up rules.rb
- d8e7469 Auto-search for config files
- 3153f06 pull out sanitization rulesets into LIB/files/rules/X.yaml
- 6d813fb Add -C option
- 059af0c Allow --cached option, default to :before
- 39a1dc0 don't use before_url and after_url in init generated config
- 765ae54 Split out IE non-selector stripping
- 75d088c Add a new Drupal rule
- 974bc13 Provide access to root urls when finding sanitization rules
- 68c1d68 Use a default config name, sitediff.yaml
- 740d816 Single site mode works!
- c8d7e05 Add store subcommand
- eeaeafb Refactor out fetching from reporting
- 5ac555e Simpler caching
- 3480cfd Add more flexible cache
- 2f3e9dd Remove Typhoeus cache
- 1dc7f2e remove stale scripts/start.sh
- d9c4abe remove stale Rakefile,
- 9a2f4c5 Fix test failure
- cca22f6 Just strip Drupal.settings
- a267aa0 Rule auto-generation
- 3e0d25b Return HTML, as well as paths
- 7bde6c7 Working sitediff init; refs #10732
- 6cad303 Pull out crawler; refs #10732
- 726e0e4 Start on init command; crawl site; refs #10732

BUGFIXES:

IMPROVEMENTS:

BACKWARDS INCOMPATIBILITIES:


## [0.0.1](https://github.com/evolvingweb/sitediff/releases/tag/v0.0.1) (April 30, 2015)

Initial Release


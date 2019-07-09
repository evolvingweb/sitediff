# SiteDiff Change Log

Contains note-worthy changes made to SiteDiff.

## Dev

- Remove support for multiple config files - use "includes" instead
- Organize tests and remove Circle CI
- Make the workflow more "configure once, use many"
- Write depth, interval, concurrency and other settings to sitediff.yaml

## v0.0.2

- Detailed installation instructions
- Always show absolute paths
- Update README
- Better error and log messages
- Write a user guide
- Don't close non-existent DBM
- Rewrite intro to sitediff
- Show URL even if cached
- For side-by-side, use the cached version(s) if appropriate
- Disallow single-site mode without caches
- Make report say whether things are cached
- Create side-by-side view
- Split out ResultServer
- Pass config to server
- Replace URI with Addressable::URI
- Serve cached files
- Better encoding
- Allow selecting whether to open in browser
- Support multiple rules, only one can match
- Print results in order
- Fix multi-selector behaviour
- Refactor sanitizations and dom transforms
- Refactor webserver; open in browser
- Abstract out complex parts of link handling
- Close cache when done
- Update spec with new exit codes: only fail test if exit code != 2
- Fix sanitization rule for Drupal.settings
- Strip view DOM IDs for Drupal
- Exit with non-zero code when we have diffs
- Introduce "diff --quiet": don't log actual diffs
- Use SiteDiff.log for showing crawl errors
- Escape crawled URLs
- Yield a failure on cache miss, instead of dying
- Prettify as part of perform RegExps; fixes #10999
- Add domain sanitization to drupal.yaml
- Skip invalid URLs while crawling + log to user while fetching
- In single-site mode, apply rules globally
- Allow "disabled" option in rules
- Put things in cache the same way we get them
- Better canonical paths
- Integrate with async rules
- Sitediff init: match rules to before and after separately
- Make init more asynchronous; add caching
- Pre-check if we have all the cached items we need
- Make all exceptions extend SiteDiffException
- Create --paths option
- Don't search when dir is specified
- Create a .gitignore file during init
- Auto-search for config files
- Put sanitization rule sets in lib/files/rules/X.yaml
- Add -C option for config directory
- Create --cached option, default to :before
- Don't use before_url and after_url in init generated config
- Split out IE non-selector stripping
- Access to root URLs when finding sanitization rules
- Use default config name: sitediff.yaml
- Single site mode works!
- Add "sitediff store" command
- Separate fetching from reporting
- Caching improvements
- Strip Drupal.settings
- Auto-generate cleanup rules
- Create SiteDiff init

# SiteDiff Change Log

Contains noteworthy changes made to SiteDiff.

## Since 1.1.1

## Version 1.1.1
- Refactor CLI class and move business logic to new SiteDiff::Api class for better integration with other Ruby apps.
- Add overlay for diff screen - JS fails back to HTML.
- Add additional information to the report output (21861).
- Restore the `before_url_report` and `after_url_report` features and improve the output of exported reports (21860).
- Added named regions feature. (See [Advanced diffs](README.md#advanced-diffs).)
- Deprecated `--whitelist` and `--blacklist`. To be removed in 1.1.0.
- Fix `init` command when running with a single URL #109
- Remove --insecure option — instead, always accept certificates.
- Update `.travis.yml` to Ruby 2.7

## Prior to 1.0.0

Release notes were out of date, so only tracking changes since 1.0.0 here.
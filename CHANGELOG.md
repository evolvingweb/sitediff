# SiteDiff Change Log

Contains noteworthy changes made to SiteDiff.
## Version 1.2.3
- Fix issue with nil object during diff report generation.
- Update to export documentation.

## Version 1.2.2
- Security update for Nokogiri.
- Minor code updates.

## Version 1.2.1
- Fixed a bug with report exporting.
- Prevents crawling the same site twice if the before and after urls are the same.
- Adding a referrer to the crawler errors.

## Version 1.2.0
- Updated requirement to Ruby 3.1.2.
- Upgraded modules for security and compatibility.
- Fixed bug in crawl command where the `after` site pages were overwriting pages in the `sitediff/before` directory.
- Fixed bug for using presets.
- Fixed bug for including other files.

## Version 1.1.2
- Security upgrades to modules.

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
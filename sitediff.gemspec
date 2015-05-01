Gem::Specification.new do |s|
  s.name        = 'sitediff'
  s.version     = '0.0.1'
  s.required_ruby_version = ">= 1.9.3"
  s.summary     = 'Compare two versions of a site with ease!'
  s.description = <<EOS
SiteDiff makes it easy to see differences between two versions of a website. It accepts a set of paths to compare two versions of the site together with potential normalization/sanitization rules. From the provided paths and configuration SiteDiff generates an HTML report of all the status of HTML comparison between the given paths together with a readable diff-like HTML for each specified path containing the differences between the two versions of the site. It is useful tool for QAing re-deployments, site upgrades, etc.
EOS
  s.license     = 'GPL-2'
  s.authors     = ['Alex Dergachev', 'Amir Kadivar', 'Dave Vasilevsky']
  s.homepage    = 'https://github.com/evolvingweb/sitediff/'
  s.email       = 'alex@evolvingweb.ca'
  s.files       = Dir.glob('lib/**/*.rb') +
                  Dir.glob('lib/sitediff/files/*') +
                  Dir.glob('lib/sitediff/files/rules/*.yaml')
  s.bindir      = 'bin'
  s.executables = 'sitediff'

  # FIXME pin down minimum version requirements
  s.add_dependency 'thor'
  s.add_dependency 'nokogiri'
  s.add_dependency 'diffy'
  s.add_dependency 'typhoeus'
  s.add_dependency 'rainbow'
  s.add_dependency 'addressable'
end

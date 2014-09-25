Gem::Specification.new do |s|
  s.name        = 'sitediff'
  s.version     = '0.0.1'
  # FIXME add Ruby version requirement
  # s.required_ruby_version = ">= 1.8.7"
  s.summary     = 'Compare two versions of a site with ease!'
  s.authors     = ['Alex Dergachev', 'Amir Kadivar', 'Dave Vasilevsky']
  s.email       = 'alex@evovlvingweb.ca'
  s.files       = Dir.glob('lib/**/*.rb') +
                  Dir.glob('lib/**/*.erb') +
                  ['lib/sitediff/util/pretty_print.xsl']
  s.bindir      = 'bin'
  s.executables = 'sitediff'
  # FIXME pin down minimum version requirements
  s.add_dependency 'thor'
  s.add_dependency 'nokogiri'
  s.add_dependency 'diffy'
end

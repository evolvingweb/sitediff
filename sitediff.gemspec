# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = 'sitediff'
  s.version     = '1.2.9'
  s.required_ruby_version = '>= 3.1.2'
  s.summary     = 'Compare two versions of a site with ease!'
  s.description = <<DESC
  SiteDiff makes it easy to see differences between two versions of a website. It accepts a set of paths to compare two versions of the site together with potential normalization/sanitization rules. From the provided paths and configuration SiteDiff generates an HTML report of all the status of HTML comparison between the given paths together with a readable diff-like HTML for each specified path containing the differences between the two versions of the site. It is useful tool for QAing re-deployments, site upgrades, etc.
DESC
  s.license     = 'GPL-2.0'
  s.authors     = ['Alex Dergachev', 'Amir Kadivar', 'Dave Vasilevsky']
  s.homepage    = 'https://sitediff.io/'
  s.email       = 'alex@evolvingweb.ca'
  s.metadata    = {
    'source_code_uri' => 'https://github.com/evolvingweb/sitediff'
  }

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  s.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  s.require_paths = ['lib']
  # s.files       = Dir.glob('lib/**/*.rb') +
  #                Dir.glob('lib/sitediff/files/*') +
  #                Dir.glob('lib/sitediff/files/rules/*.yaml')
  s.bindir      = 'bin'
  s.executables = 'sitediff'

  # Apparently we require pkg-config
  s.add_dependency 'pkg-config', '~> 1.4'

  s.add_dependency 'minitar', '~> 0.9'
  s.add_dependency 'thor', '~> 1.2.1'
  s.add_dependency 'typhoeus', '>= 1.1.1'

  # A bug in rubygems can break rainbow 2.2
  # https://github.com/bundler/bundler/issues/5357
  s.add_dependency 'rainbow', '~> 3.1.1'

  # Nokogiri 1.7 is not supported on Ruby 2.0.
  s.add_dependency 'nokogiri', '>= 1.14.2'

  # Diffy and addressable have a max version for Ruby 1.9.
  s.add_dependency 'addressable', '>= 2.5.2', '< 2.9.0'
  s.add_dependency 'diffy', '~> 3.4.0'
  s.add_dependency 'webrick', '>= 1.7'
end

require 'yaml'

module SiteDiff
  module Config
    @@config ||= YAML.load_file("config.yaml")

    def self.prod_url
      @@config["sites"]["prod"]["url"]
    end

    def self.dev_url
      @@config["sites"]["dev"]["url"]
    end

    def self.prod_site
      @@config["sites"]["prod"]
    end

    def self.dev_site
      @@config["sites"]["dev"]
    end
  end
end

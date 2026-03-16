require_relative "lib/happy_slugs/version"

Gem::Specification.new do |spec|
  spec.name = "happy_slugs"
  spec.version = HappySlugs::VERSION
  spec.authors = ["Carl Dawson"]
  spec.summary = "Pleasant, random, human-readable slugs for ActiveRecord models"
  spec.homepage = "https://github.com/carldaws/happy_slugs"
  spec.license = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir["lib/**/*"]
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 7.0"
end

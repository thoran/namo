require_relative './lib/Namo/VERSION'

Gem::Specification.new do |spec|
  spec.name = 'namo'
  spec.version = Namo::VERSION

  spec.summary = "Named dimensional data for Ruby."
  spec.description = "A Ruby library for working with multi-dimensional data using named dimensions. Initialise from an array of hashes making it trivial to use with databases, CSV, JSON, and YAML. Dimensions and coordinates are inferred automatically."

  spec.author = 'thoran'
  spec.email = 'code@thoran.com'
  spec.homepage = 'https://github.com/thoran/namo'
  spec.license = 'MIT'

  spec.required_ruby_version = '>= 2.7'
  spec.require_paths = ['lib']

  spec.files = [
    'CHANGELOG',
    'Gemfile',
    Dir['lib/**/*.rb'],
    'LICENSE',
    'namo.gemspec',
    'Rakefile',
    'README.md',
    Dir['test/**/*.rb'],
  ].flatten

  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'minitest-spec-context'
  spec.add_development_dependency 'rake'
end

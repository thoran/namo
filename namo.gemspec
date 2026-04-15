require_relative './lib/Namo/VERSION'

class Gem::Specification
  def development_dependencies=(gems)
    gems.each{|gem| add_development_dependency(*gem)}
  end
end

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
    'namo.gemspec',
    'CHANGELOG',
    'Gemfile',
    'LICENSE',
    'Rakefile',
    'README.md',
    Dir['lib/**/*.rb'],
    Dir['test/**/*.rb'],
  ].flatten

  spec.development_dependencies = %w{
    minitest
    minitest-spec-context
    rake
  }
end

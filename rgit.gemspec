# frozen_string_literal: true

require_relative "lib/rgit/version"

Gem::Specification.new do |spec|
  spec.name          = "rgit"
  spec.version       = Rgit::VERSION
  spec.authors       = ["David Avedissian"]
  spec.email         = ["git@dga.dev"]

  spec.summary       = "Reimplementation of git in Ruby."
  # spec.description   = "TODO: Write a longer description or delete this line."
  spec.homepage      = "https://github.com/dgavedissian/rgit"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.4.0"

  # spec.metadata["allowed_push_host"] = "TODO: Set to 'https://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  # spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'iniparse', '~> 1.4', '>= 1.4.2'
  spec.add_dependency 'main', '~> 6.1'

  # For more information and examples about making a new gem, checkout our
  # guide at: https://bundler.io/guides/creating_gem.html
end

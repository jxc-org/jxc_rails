# frozen_string_literal: true

require_relative "lib/jxc_rails/version"

Gem::Specification.new do |spec|
  spec.name = "jxc_rails"
  spec.version = JxcRails::VERSION
  spec.authors = ["Maximilian Coulter"]
  spec.email = ["johnxcoulter@gmail.com"]

  spec.summary = "Shared Rails conventions for jxc-org apps."
  spec.description = "Hotwire Native version gating, persistent login, short-code IDs, and other shared Rails patterns used across jxc-org applications."
  spec.homepage = "https://github.com/jxc-org/jxc_rails"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata["allowed_push_host"] = "https://rubygems.pkg.github.com/jxc-org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "railties", ">= 7.1"
  spec.add_dependency "activesupport", ">= 7.1"
end

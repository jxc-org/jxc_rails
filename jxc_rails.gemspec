# frozen_string_literal: true

require_relative "lib/jxc_rails/version"

Gem::Specification.new do |spec|
  spec.name = "jxc_rails"
  spec.version = JxcRails::VERSION
  spec.authors = ["Maximilian Coulter"]
  spec.email = ["johnxcoulter@gmail.com"]

  spec.summary = "Shared Rails conventions for jxc-org apps."
  spec.description = "Hotwire Native version gating, persistent login, short-code IDs, and other shared Rails patterns " \
                     "used across jxc-org applications."
  spec.homepage = "https://github.com/jxc-org/jxc_rails"
  spec.required_ruby_version = ">= 3.4.0"
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

  # Shared runtime stack ("BOM"): jxc_rails is the single source of truth for the
  # version constraints of the gems every jxc-org Rails app depends on. Apps drop
  # these from their own Gemfiles and inherit them transitively; bump them HERE,
  # tag a release, and apps pin to the tag. See CONTRIBUTING.md "Versioning".
  #
  # Pins are pessimistic and reconciled to the convergence target across apps.
  # NOTE: solid_cable ~> 4.0 (not 3.x) intentionally pulls every app up to 4.0 —
  # gigq is already there; lumberlog/birthdaze adopt the safe 3->4 bump (reconnect/
  # retry only, no DB migration). solid_cable 4.0 drops Ruby < 3.3, hence the 3.4 floor.
  # rails subsumes the former activesupport/railties deps; devise is integrated by
  # persistent_login; thruster wraps puma in production. (Ordered alphabetically per
  # Gemspec/OrderedDependencies.)
  spec.add_dependency "bootsnap", "~> 1.18"
  spec.add_dependency "devise", "~> 5.0"
  spec.add_dependency "image_processing", "~> 2.0"
  spec.add_dependency "importmap-rails", "~> 2.2"
  spec.add_dependency "pg", "~> 1.1"
  spec.add_dependency "propshaft", "~> 1.3"
  spec.add_dependency "puma", ">= 5.0"
  spec.add_dependency "rails", "~> 8.1.3"
  spec.add_dependency "ruby-vips", "~> 2.0"
  spec.add_dependency "solid_cable", "~> 4.0"
  spec.add_dependency "solid_cache", "~> 1.0"
  spec.add_dependency "solid_queue", "~> 1.4"
  spec.add_dependency "stimulus-rails", "~> 1.3"
  spec.add_dependency "thruster", "~> 0.1"
  spec.add_dependency "turbo-rails", "~> 2.0"
end

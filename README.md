# jxc_rails

Shared Rails conventions for jxc-org applications (birthdaze, gigq, lumberlog, and future apps).

## Modules

- **`JxcRails::HotwireNative`** — version-aware `path_configuration.json` for Hotwire Native clients, force-upgrade gating based on app version.
- **`JxcRails::PersistentLogin`** — Devise `remember_me` auto-applied for Hotwire Native clients so mobile users aren't logged out after two weeks.
- **`JxcRails::ShortCode`** — `has_short_code` DSL for nanoid-style public identifiers with configurable alphabets.
- **`JxcRails::VariantProcessorCheck`** — boot-time guard that fails fast when a dependency bump drops the gem backing the configured ActiveStorage variant processor (e.g. `image_processing` 2.x dropping `ruby-vips`). Wired automatically by the Railtie; runs in `after_initialize` (incl. `assets:precompile`).

## Installation

```ruby
# Gemfile
gem "jxc_rails", github: "jxc-org/jxc_rails"
```

## Configuration

```ruby
# config/initializers/jxc_rails.rb
JxcRails.configure do |c|
  c.hotwire_native.app_name        = "Birthdaze"
  c.hotwire_native.min_app_version = "2.0.0"
  c.persistent_login.remember_for  = 1.year
  c.short_code.default_length      = 8

  # Variant-processor guard (defaults shown). Raises on a missing backing gem in
  # `production` (crashloops the new pod / fails the Docker build), warns elsewhere.
  c.variant_processor_check.enabled            = true
  c.variant_processor_check.raise_environments = %w[production]
end
```

## Variant processor guard

Catches the class of bug where a dependency bump passes the test suite but breaks
a runtime path. The motivating incident: `image_processing` 1.x → 2.x dropped its
auto-bundled `ruby-vips`, so apps using `variant_processor = :vips` kept calling
`photo.variant(...)` but the backing gem was gone — RSpec stayed green because no
test processed a variant.

Two layers, both shipped here so every app inherits them:

1. **Boot assertion** (`VariantProcessorCheck.run!`, via the Railtie) — verifies the
   configured processor's backing gem is in the bundle. Cheap, no native libvips
   load, so it's safe during `assets:precompile` and gates the Docker image even
   for apps with no test job.
2. **Functional smoke** (`rake jxc_rails:variant_processor:smoke`) — processes a
   real embedded image through the configured processor. Run it in CI (where
   libvips is installed), especially on `Gemfile`/`Gemfile.lock` changes, to also
   catch native-library and API breakage.

## Status

Scaffold only. Module implementations pending.

| Module | Status |
|---|---|
| `HotwireNative` | skeleton |
| `PersistentLogin` | skeleton |
| `ShortCode` | skeleton |
| `VariantProcessorCheck` | implemented |

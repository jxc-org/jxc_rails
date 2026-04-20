# jxc_rails

Shared Rails conventions for jxc-org applications (birthdaze, gigq, lumberlog, and future apps).

## Modules

- **`JxcRails::HotwireNative`** — version-aware `path_configuration.json` for Hotwire Native clients, force-upgrade gating based on app version.
- **`JxcRails::PersistentLogin`** — Devise `remember_me` auto-applied for Hotwire Native clients so mobile users aren't logged out after two weeks.
- **`JxcRails::ShortCode`** — `has_short_code` DSL for nanoid-style public identifiers with configurable alphabets.

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
end
```

## Status

Scaffold only. Module implementations pending.

| Module | Status |
|---|---|
| `HotwireNative` | skeleton |
| `PersistentLogin` | skeleton |
| `ShortCode` | skeleton |

# jxc_rails

Shared Rails conventions for jxc-org applications (birthdaze, gigq, lumberlog, and future apps).

## Modules

- **`JxcRails::HotwireNative`** — version-aware `path_configuration.json` for Hotwire Native clients, force-upgrade gating based on app version.
- **`JxcRails::PersistentLogin`** — Devise `remember_me` auto-applied for Hotwire Native clients so mobile users aren't logged out after two weeks.
- **`JxcRails::ShortCode`** — `has_short_code` DSL for nanoid-style public identifiers with configurable alphabets.
- **`JxcRails::SystemSpecs`** — makes browser specs tell the truth in CI: a missing browser **raises instead of skipping**, and viewports are named, applied with `resize_to`, and verified. See [Browser specs that don't lie](#browser-specs-that-dont-lie).
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

## Browser specs that don't lie

Two ways a green suite can be a lie. Both shipped real defects past review on
2026-08-22 (gigq#75, gigq#78), and both are invisible by construction — there is
nothing red to notice.

### Failure mode 1: the silent-skip cliff

Every browser spec in the fleet opened with some spelling of:

```ruby
skip "headless Chrome not available" unless chrome_installed?
```

**A skip is not a failure.** If the runner stops shipping a browser, every
browser spec in the app stops executing — forever — and CI stays green. Nothing
warns you, because a skipped example and a passing one look the same from the
merge button.

This is not hypothetical. jxc-org's browser specs execute today *only* because
the org's `CI_RUNNER` variable happens to resolve to `ubuntu-latest`, which
ships Chrome. Flipping the fleet back to the self-hosted `homeserver-linux`
image would zero all browser coverage, org-wide, with no red anywhere.

So the rule is environment-dependent, because the intent is:

| Where | Browser missing means |
|---|---|
| Local dev | **Skip.** Not every dev has a driver installed; that's fine. |
| CI (`ENV["CI"]`) | **Raise.** A build that can't run browser specs is a broken build. |

The raise message says what to install, where, and why skipping is banned —
because the fix is always the *runner*, never the spec.

### Failure mode 2: the silent viewport

The obvious way to size a browser spec is a driver argument:

```ruby
# Looks right. Does nothing.
Selenium::WebDriver::Chrome::Options.new(args: %w[--window-size=390,844])
```

**Chrome's `--window-size` does not survive Capybara's driver setup.** Specs
passing it were observed running at ~1257px regardless of what they asked for.
Every spec that doesn't explicitly resize therefore runs at an arbitrary width
that nothing in the product actually ships at — so viewport-dependent bugs are
structurally invisible to it. A real spec passed against CSS that was broken at
the width its feature ships at.

So viewports here are: **named**, **applied with `resize_to`** (never driver
args), and **verified** — the helper reads `window.innerWidth` back from the
browser and raises if the resize didn't take. Trusting the resize is what
produced the bug.

| Name | Size | Matches |
|---|---|---|
| `:phone_old` | 390x844 | iPhone 12–13 / 14 class |
| `:phone_new` | 402x874 | iPhone 16 class |
| `:desktop` | 1280x900 | fleet desktop screenshot width |

### Failure mode 3: the silent Chrome argument

The obvious way to hand Chrome its flags is `driven_by`'s `options:` keyword:

```ruby
# Looks right. Delivers nothing.
driven_by(:selenium, using: :headless_chrome,
          options: { options: Selenium::WebDriver::Chrome::Options.new(args: %w[--disable-dev-shm-usage]) })
```

Rails throws it away. `ActionDispatch::SystemTesting::Driver#browser_options` is

```ruby
@options.merge(options: @browser.options)
```

— the caller's `:options` is *overwritten* by the `Chrome::Options` Rails built
for itself. No warning, no deprecation: Chrome simply launches without the
flags.

Nothing green could have caught it. `ubuntu-latest` and dev laptops have a roomy
`/dev/shm`, so a missing `--disable-dev-shm-usage` costs nothing there. On the
self-hosted ARC runners — a container whose `/dev/shm` is the 64MB default — the
first handful of browser specs pass, `/dev/shm` fills, and every one after it
dies with `Selenium::WebDriver::Error::WebDriverError: tab crashed`.

The seam Rails actually honours is the block, which yields that very options
object:

```ruby
driven_by(:selenium, using: :headless_chrome) { |options| options.add_argument("--disable-dev-shm-usage") }
```

`drive_headless_chrome!` does this for you, and a spec asserts on the arguments
Rails hands to Capybara — not on the shape of the hash we passed in — so the
plumbing itself stays covered.

### Usage

Once per app, in `spec/rails_helper.rb`:

```ruby
require "jxc_rails/system_specs"
JxcRails::SystemSpecs.install!(RSpec.configuration)
```

Then each browser spec's `before` block replaces the whole copy-pasted preamble
with one line:

```ruby
RSpec.describe "Audience catalog", type: :system, js: true do
  before { drive_headless_chrome!(viewport: :phone_new) }
  # ...
end
```

`install!` wires three things onto every `type: :system` example:

1. a `prepend_before` browser gate — raises in CI, skips locally;
2. the helpers (`drive_headless_chrome!`, `use_viewport`, `viewport`);
3. an `after` **viewport guard** — fails any example that ran in a real browser
   without declaring a viewport, or whose viewport drifted after it was applied.

To change the viewport mid-example (e.g. assert a responsive breakpoint both
ways), call `use_viewport(:desktop)` again; it re-verifies.

### Why a guard *and* a default

The default (`config.system_specs.default_viewport`, `:desktop`) makes the easy
path deterministic. The after-hook guard makes the *lazy* path loud: a spec that
forgets to declare a viewport fails rather than silently running at ~1257px.

What was rejected, and why:

- **A `--window-size` driver arg** — this is failure mode 2 itself. It is
  silently discarded, which is the entire problem.
- **Passing Chrome args through `driven_by(options:)`** — failure mode 3. Rails
  overwrites the key; the args never reach the browser.
- **A config-level `before` hook that resizes every system spec automatically** —
  RSpec runs config-level hooks *before* group-level ones, so it would fire
  before the spec's own `driven_by`, resize a driver that doesn't exist yet, and
  then be silently undone when `driven_by` builds the real one. Worse than
  nothing: it looks enforced and isn't.
- **Requiring `viewport:` metadata on every browser example group** — same
  ordering problem for applying it, and it can't catch a spec that re-drives
  itself mid-example.
- **Trusting `resize_to` without reading the width back** — the whole lesson of
  failure mode 2 is that the ask and the result can differ silently.

Width is checked, height isn't: width is what CSS breakpoints key off, while
`innerHeight` varies with browser chrome and headless mode. A 20px tolerance
absorbs a classic scrollbar without absorbing real drift.

### Configuration

```ruby
JxcRails.configure do |c|
  c.system_specs.default_viewport = :desktop                          # default
  c.system_specs.browser_args     = %w[--no-sandbox --disable-dev-shm-usage]
end
```

Note `browser_args` carries no `--window-size`, on purpose.

### Proving the failure path (the RED-not-skip drill)

Set `JXC_RAILS_FORCE_BROWSER_ABSENT=1` to make the gem report the browser as
missing without uninstalling anything. In CI that turns the build red; locally
it skips. Use it to verify a repo's browser specs actually fail when the browser
goes away — never to make a red build green.

## Status

Scaffold only. Module implementations pending.

| Module | Status |
|---|---|
| `HotwireNative` | skeleton |
| `PersistentLogin` | skeleton |
| `ShortCode` | skeleton |
| `SystemSpecs` | implemented |
| `VariantProcessorCheck` | implemented |

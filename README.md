# jxc_rails

Shared Rails conventions for jxc-org applications (birthdaze, gigq, lumberlog, and future apps).

## Modules

- **`JxcRails::HotwireNative`** — version-aware `path_configuration.json` for Hotwire Native clients, force-upgrade gating based on app version.
- **`JxcRails::HotwireNative::Theme`** — native colors (`theme` + `background_color`) in the path-configuration settings, validated for WCAG contrast at boot. See [Native theme](#native-theme-in-the-path-configuration).
- **`JxcRails::PersistentLogin`** — Devise `remember_me` auto-applied for Hotwire Native clients so mobile users aren't logged out after two weeks.
- **`JxcRails::ShortCode`** — `has_short_code` DSL for nanoid-style public identifiers with configurable alphabets.
- **`JxcRails::SystemSpecs`** — makes browser specs tell the truth in CI: a missing browser **raises instead of skipping**, and viewports are named, applied with `resize_to`, and verified. See [Browser specs that don't lie](#browser-specs-that-dont-lie).
- **`JxcRails::Push`** — push notifications over `action_push_native` (direct APNs): `Model` concern for `ApplicationPushDevice` (`register` upserts by token, `unregister` for sign-out), `ControllerConcern` for a devices controller. Skips sends with one log line while APNs credentials are unset. See [Push notifications](#push-notifications).
- **`JxcRails::R2Storage`** — Cloudflare R2 as the standard Active Storage backend: an `r2` storage.yml block, a boot check, and `jxc_rails:storage:{install,check}` tasks. See [Storing files in R2](#storing-files-in-r2).
- **`JxcRails::TimeZone`** — per-user IANA time zones: `Model` concern (validation + `effective_time_zone`), `ControllerConcern` (captures the `jxc_tz` cookie into a blank zone, never overwrites; wraps requests in `Time.use_zone`), `jxc_time_zone_capture_tag` view helper (inline script, no bundle), and `JxcRails::TimeZone.use_for(user) { ... }` for jobs/mailers. Default zone `c.time_zone.default` (`America/New_York`).
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

## Native theme in the path configuration

Serve the app's colors inside the Hotwire Native path-configuration `settings`, so iOS follows the web without an
App Store build. Not configured = path-configuration output unchanged.

```ruby
# config/initializers/jxc_rails.rb
JxcRails.configure do |c|
  # Each role: a CSS custom property from :root of css_path, or a literal "#RRGGBB" (Tailwind apps).
  c.hotwire_native.theme.light = { background: "--bg", surface: "--surface", border: "--border",
                                   text: "--text", accent: "--coral-strong" }
  c.hotwire_native.theme.dark  = { background: "#111111", surface: "#1C1C1C", border: "#333333",
                                   text: "#F5F5F5", accent: "#FF8A6B" } # optional
  c.hotwire_native.theme.css_path = "app/assets/stylesheets/application.css" # default
end
```

```ruby
# app/views/hotwire_native/path_configuration.json.jbuilder
json.settings do
  hotwire_theme(json) # adds theme: {version: 1, light:, dark:} and background_color (= light background)
end
```

Roles: `background` window and web-view background; `surface` nav-bar fill; `border` nav-bar hairline; `text` native
error screens (and optional nav title); `accent` tint and nav title. Every value must be `#RRGGBB` (no `rgb()`),
and `text` on `background`/`surface` and `accent` on `surface`/`background` must reach WCAG 2.x 4.5:1 (light, and
dark when given). The theme is resolved once at boot. A missing variable, non-hex value or contrast failure raises
`JxcRails::ConfigurationError` in the test environment (so CI fails) and elsewhere is logged once and omitted.
Clients should refresh it at most every 15 minutes on foreground.

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

## Storing files in R2

Cloudflare R2 is the standard Active Storage backend. To switch an app over:

1. `bin/rails jxc_rails:storage:install`: appends an `r2:` service to
   `config/storage.yml` and `gem "aws-sdk-s3", require: false` to the Gemfile
   (each only if absent; safe to re-run). Then `bundle install`.
2. Set four env vars (from the app's secrets, never committed):
   `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET`.
3. One line in `config/environments/production.rb`:
   `config.active_storage.service = :r2`

The generated block is gigq's: endpoint `https://<R2_ACCOUNT_ID>.r2.cloudflarestorage.com`,
`region: auto`, and `request_checksum_calculation` / `response_checksum_validation`
set to `when_required` (R2 rejects the checksums newer `aws-sdk-s3` versions send by default).

**Boot check.** When the service is `:r2`, boot raises `JxcRails::ConfigurationError`
if `aws-sdk-s3` is not in the bundle or any of the four env vars is missing or blank.
The error names the variable and never prints a value. When `SECRET_KEY_BASE_DUMMY`
is set (the Rails Dockerfile's `assets:precompile`), the env-var check is skipped
but the gem check still runs.

**Operator check.** `bin/rails jxc_rails:storage:check` HEADs the bucket and
puts/gets/deletes a small object under `_jxc_rails_probe/`, then prints `PASS` or
`FAIL <error class>: <message>` (exits 1 on failure). It never prints credentials.

**Buckets and tokens.** Buckets are created in homeserver-infra
`terraform/cloudflare/r2.tf`. Per-bucket API tokens are minted by Max in the
Cloudflare dashboard: one token per bucket, never shared between apps.

## Push notifications

Run `bin/rails action_push_native:install:migrations db:migrate` and the gem's install generator (it creates
`ApplicationPushDevice` and `config/push.yml`), then:

```ruby
class ApplicationPushDevice < ActionPushNative::Device
  include JxcRails::Push::Model            # owner is the user
end

class DevicesController < ApplicationController   # POST token=…, DELETE /devices/:id
  include JxcRails::Push::ControllerConcern
end
# routes: resources :devices, only: %i[create destroy]

# on sign-out, with the token or device id the client sent for this session:
ApplicationPushDevice.unregister(owner: user, token: token)
```

An APNs 410 or `BadDeviceToken` destroys the device (action_push_native does this itself). While `config/push.yml`
has no APNs key, `device.push` logs one line and returns, so an app can deploy before the key exists. The token and
payload are never logged.

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

**Chrome's `--window-size` is overridden.** Specs passing it were observed
running at ~1257px regardless of what they asked for.

It is worth being exact about what overrides it, because "Capybara discards it"
— the original reading — is wrong. It is Rails, in two different places:

1. **Before v0.3.2 the argument never reached Chrome at all**, because it went
   through `driven_by`'s `options:` keyword. That is failure mode 3 below.
2. **Even delivered, it is undone a moment later.**
   `ActionDispatch::SystemTesting::Driver#register_selenium` resizes the window
   to `screen_size` (default `[1400, 1400]`) as soon as the driver exists.
   Measured: `--window-size=390,844` reaches Chrome's command line and the
   session still reports `innerWidth=1400`.

The advice is unchanged; the reason is now known.

Every spec that doesn't explicitly resize therefore runs at an arbitrary width
that nothing in the product actually ships at — so viewport-dependent bugs are
structurally invisible to it. A real spec passed against CSS that was broken at
the width its feature ships at.

So viewports here are: **named**, **applied with `resize_to`** (never driver
args), and **verified** — the helper reads `window.innerWidth` back from the
browser and raises if the resize didn't take. Trusting the resize is what
produced the bug.

**`resize_to` has a floor on macOS (v0.3.3).** Headless Chrome there won't size
a window below **500px** wide: measured on Chrome 152, `resize_to(402, 874)`,
`(390, 844)` and `(450, …)` all leave `innerWidth` *and* `outerWidth` at exactly
500, while `resize_to(600, …)` takes. Linux CI Chromium has no such floor, which
is why phone viewports passed in CI and raised locally. So on Chromium drivers
the helper also sets the layout viewport over CDP
(`Emulation.setDeviceMetricsOverride`), which is independent of the OS window.
`resize_to` is kept (non-Chromium drivers have nothing else). The `innerWidth`
check is **unchanged** and still decides: the CDP call is a second way to *set*
the width, not a reason to trust it.

**The CDP call is rescued (v0.3.4).** `respond_to?(:execute_cdp)` proves the
method exists, not that the session accepts the command — a remote grid without a
CDP endpoint answers it and then fails. A failed override is simply not an
override: the `innerWidth` check runs next and raises `ViewportError` with the
real measured width, the same as before CDP existed. Without the rescue, a driver
that cannot do CDP would start failing viewports that `resize_to` alone already
handled.

**The CDP override is a fallback, not the default (v0.3.5).** It is sticky: it
beats every later `resize_to` until cleared. v0.3.3/0.3.4 set it on *every*
`apply_viewport!`, so a spec that drove a named viewport and then resized itself
(`drive_headless_chrome!(viewport: :desktop)`, then `resize_to(1440, 900)`) stayed
at 1280 — on Linux too. Now `apply_viewport!` clears any stale override, calls
`resize_to`, and sets the override only if the measured width is still off. Where
`resize_to` alone works (all of Linux CI) no override is ever set.

Known limit (macOS only): after a *floor-clamped* phone viewport (<500px), a raw
`resize_to` in the spec is still pinned by the override that phone needed. Go back
through `apply_viewport!`/`use_viewport`, which clears it first.

Note what the override does **not** do: `mobile: false` means no touch emulation,
no device-pixel-ratio change and no mobile user-agent. It sets the layout viewport
so media queries see the width you asked for. That is the right default for
screenshotting a responsive layout, and it is not device emulation.

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

- **A `--window-size` driver arg** — this is failure mode 2 itself. Rails
  resizes the window out from under it, which is the entire problem.
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

All modules are implemented and in use by the Rails apps.

| Module | Status | Used by |
|---|---|---|
| `HotwireNative` | implemented | birthdaze, costco-checker, gigq, lumberlog |
| `PersistentLogin` | implemented | birthdaze, costco-checker, gigq, lumberlog |
| `ShortCode` | implemented | birthdaze, gigq |
| `R2Storage` | implemented | — |
| `SystemSpecs` | implemented | — |
| `TimeZone` | implemented | — |
| `VariantProcessorCheck` | implemented | — |

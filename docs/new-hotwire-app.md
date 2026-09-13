# Creating a new Rails + Hotwire Native app

How to stand up app #5 the way apps #1–#4 are actually built, rather than the way
any one of them happens to be built.

**Derived: 2026-09-13**, by measuring `birthdaze`, `costco-checker`, `gigq` and
`lumberlog` against their **fetched `origin/main`** — not the local checkouts,
every one of which was 8–19 days stale at the time. Re-derive before trusting any
specific claim here; each section says which command produced it.

> **Why this document exists, and the risk it carries.** The four apps disagree in
> about a dozen places. Until now the only way to start app #5 was to copy whichever
> app you opened first, which is how the disagreements got there. A guide fixes that —
> but it also *launders* whatever it documents into policy. So every item below is
> sorted into one of three buckets, and the bucket is always visible:
>
> | | meaning |
> |---|---|
> | **[CONVENTION]** | consistent across the apps. Copy it. |
> | **[CORRECTED]** | the apps disagree, and there is a defensible right answer. The reason is stated. |
> | **[OPEN]** | the apps disagree and **nobody has decided**. Do not let this document decide it for you. |
>
> There are **two [OPEN] items**. They are collected in [Open questions](#open-questions)
> and are not resolved here on purpose — picking arbitrarily would convert an accident
> into a convention, which is worse than leaving it visibly undecided. A third (the
> build-number seed) was closed by measurement rather than by preference; the reasoning
> is recorded in §2.1 so it can be overturned on better grounds.

---

## Before you start

You need, and this guide assumes:

- `xcodegen` (`brew install xcodegen`) — the `.xcodeproj` is **generated, not edited**.
- Xcode with an iOS 17+ simulator.
- The Rails app already exists and is deployed somewhere reachable over HTTPS.
- An App Store Connect app record, if you intend to ship to TestFlight.

The iOS app is a thin wrapper. **Nothing about your product's behaviour belongs in
Swift** — it belongs in the Rails app, and the wrapper renders it. The Swift you
write is navigation, chrome, and bridge components.

---

## Part 1 — the Rails side

### 1.1 Add the gem  [OPEN — see Q2]

```ruby
# Gemfile
gem "jxc_rails", github: "jxc-org/jxc_rails"
```

All four apps depend on `jxc_rails`, but **each of them pins it differently** — this
is [OPEN question Q2](#q2--pin-or-float-jxc_rails). Pick deliberately.

### 1.2 Configure it  [CONVENTION]

Every app has `config/initializers/jxc_rails.rb`. Verified present in all four.

```ruby
JxcRails.configure do |config|
  config.hotwire_native.app_name           = "YourApp"
  config.hotwire_native.min_app_version    = nil
  config.hotwire_native.force_upgrade_path = "/app/must-upgrade"

  config.persistent_login.remember_for           = 1.year
  config.persistent_login.extend_remember_period = true
end
```

`min_app_version = nil` disables force-upgrade until you have a reason to use it.

### 1.3 The path configuration  [CONVENTION, with one [CORRECTED] detail]

The path configuration tells Hotwire Native how to present each URL — push, modal,
or replace-root. It is **authored once in Rails** and consumed in two places: served
live at `/hotwire-native/path-configuration`, and bundled into the app so the first
screen has rules before any network call completes.

Create `app/views/hotwire_native/path_configuration.json.jbuilder`:

```ruby
json.settings do
  json.tabs []
  json.background_color "#F8FAFC"
end

json.rules do
  if @hotwire_force_upgrade
    rule json, patterns: [ ".*" ],
      presentation: "replace_root",
      redirect_url: JxcRails.config.hotwire_native.force_upgrade_path
    next
  end

  rule json, patterns: [ "^/$" ],
    presentation: "replace_root", pull_to_refresh_enabled: true

  rule json, patterns: [ "/users/sign_in" ], presentation: "replace_root"
  rule json, patterns: [ "/users/password" ], presentation: "modal"

  rule json, patterns: [ ".*" ],
    presentation: "push", pull_to_refresh_enabled: true
end
```

Add `lib/tasks/hotwire_native.rake` to render it to disk. Reference version, measured
from `costco-checker/lib/tasks/hotwire_native.rake` at `origin/main` (`40079eccc2`) —
the two app-specific lines are marked:

```ruby
namespace :hotwire_native do
  desc "Render path_configuration.json.jbuilder to config/hotwire_native/path_configuration.json for the iOS bundle"
  task generate_ios_path_config: :environment do
    require "yaml"
    require "json"
    project_yml = YAML.load_file(Rails.root.join("ios/project.yml"))
    base = project_yml.dig("targets", "CostcoChecker", "settings", "base") || {}  # app-specific — Xcode target name
    version = base.fetch("MARKETING_VERSION")
    build = base.fetch("CURRENT_PROJECT_VERSION").to_s
    client = JxcRails::HotwireNative::ClientVersion.new(
      app_name: "CostcoChecker",  # app-specific — same target name as the dig key above
      version: version,
      build: build
    )
    body = ApplicationController.renderer.render(
      template: "hotwire_native/path_configuration",
      formats: [ :json ],
      assigns: {
        "hotwire_client" => client,
        "hotwire_force_upgrade" => false
      }
    )
    output = Rails.root.join("config/hotwire_native/path_configuration.json")
    FileUtils.mkdir_p(output.dirname)
    File.write(output, JSON.pretty_generate(JSON.parse(body)) + "\n")
    puts "Wrote #{output.relative_path_from(Rails.root)} (version #{version}, build #{build})"
  end
end
```

Field mapping, so nothing here needs to be reverse-engineered from the source:

- `project_yml.dig("targets", "CostcoChecker", "settings", "base")` — the key is the
  Xcode target name in `ios/project.yml`. Replace `"CostcoChecker"` with your target
  name.
- `version` ← `MARKETING_VERSION`, `build` ← `CURRENT_PROJECT_VERSION` (stringified),
  both from that same target's `base` settings.
- `ClientVersion.new(app_name: "CostcoChecker", …)` — use the same target name as the
  `dig` key above.
- `app_name` is informational only: `force_upgrade_via_min_version?` (in
  `jxc_rails/lib/jxc_rails/hotwire_native/force_upgrade.rb`) compares
  `client.below?(min_app_version)` and never reads `app_name`; `ClientVersion#app_name`
  is only used by `to_s`. Don't agonise over what to name it.
- The rendered template is `hotwire_native/path_configuration` (json), assigned
  `hotwire_client` and `hotwire_force_upgrade: false`; output goes to
  `config/hotwire_native/path_configuration.json`.

(The jbuilder template above never actually emits `version` or `build` — see the
`CURRENT_PROJECT_VERSION` note in [§2.1](#21-iosprojectyml--convention--two-open--one-corrected):
the version-aware render is currently a no-op on output.)

Add a Makefile target:

```make
ios-path-config: ## Render bundled path-configuration.json for iOS from the jbuilder template
	bundle exec rake hotwire_native:generate_ios_path_config
```

**[CORRECTED] The bundled copy must be a symlink, and you must verify it resolves.**
`ios/<App>/path-configuration.json` is a symlink to
`../../config/hotwire_native/path_configuration.json` in three of the four apps
(`git ls-tree` mode `120000`). That is right: one file, no copy step, no drift.

The correction is not the symlink — it is that **nothing checks the symlink resolves,
and a dangling one is invisible to every check these repos run.** It is not a lint
error, not a test failure, and `xcodegen` treats it as *absence* rather than as
breakage. `gigq`'s is dangling on `main` right now (commit `a223a7c`, 2026-04-19,
deleted the target and left the link), and the consequence is silent and total:

```
$ cd ios && xcodegen generate && grep -c 'path-configuration' <App>.xcodeproj/project.pbxproj
```

| app | bundled file | refs in generated project |
|---|---|---|
| birthdaze | symlink, resolves | 4 |
| costco-checker | symlink, resolves | 4 |
| lumberlog | real file | 4 |
| **gigq** | **symlink, dangling** | **0** |

xcodegen skips an unresolvable symlink **without warning**. `lumberlog` shows the
explicit `sources:` entry is not what matters — it gets all 4 references without one.
The dangling link is the whole cause.

**So after creating the symlink, run that grep once.** It is two seconds and it is the
only signal you will get. If it prints `0`, the file is not in your app — and because
`AppDelegate` force-unwraps `Bundle.main.url(forResource: "path-configuration", ...)`,
that is a launch-time crash rather than a graceful fallback to the `.server` source
listed right beside it.

This was confirmed by building, not by reasoning: a simulator build of `gigq` from
`main` **succeeds**, and the resulting `GigQ.app` contains no `path-configuration.json`
(control: the same build of `costco-checker` contains it). A green build is not evidence
the resource is there.

### 1.4 Rails scaffolding  [CONVENTION]

All four repos carry: `Dockerfile`, `.kamal/`, `config/deploy.yml`, `.gitleaks.toml`,
`.rubocop.yml`, `.tool-versions`, and a `Makefile`. Three of four also carry
`lefthook.yml` — **`costco-checker`, the template this guide otherwise follows, is the
one missing it.** Include it.

---

## Part 2 — the iOS app

Everything lives in `ios/`. **Follow `costco-checker`** — newest of the four
(first commit 2026-05-10), so it carries the conventions as they settled — with
the specific backfills called out below.

### 2.1 `ios/project.yml`  [CONVENTION + two [OPEN] + one [CORRECTED]]

```yaml
name: YourApp
options:
  bundleIdPrefix: com.example          # must match your bundle ID — see below
  deploymentTarget:
    iOS: "17.0"
configs:
  Debug: debug
  Release: release
settings:
  DEVELOPMENT_TEAM: PUHY9G5JNJ

packages:
  HotwireNative:
    url: https://github.com/jxc-org/hotwire-native-ios
    branch: main

targets:
  YourApp:
    type: application
    platform: iOS
    sources:
      - YourApp
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.example.yourapp
        INFOPLIST_KEY_UIApplicationSceneManifest_Generation: false
        GENERATE_INFOPLIST_FILE: true
        INFOPLIST_FILE: YourApp/Info.plist
        CODE_SIGN_ENTITLEMENTS: YourApp/YourApp.entitlements
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        SWIFT_VERSION: "5.0"
        SUPPORTED_PLATFORMS: "iphoneos iphonesimulator"
        SDKROOT: iphoneos
        MARKETING_VERSION: "1.0.0"
        CURRENT_PROJECT_VERSION: 2          # [CORRECTED] — a placeholder, see below
      configs:
        Debug:
          CODE_SIGN_STYLE: Automatic
        Release:                            # [OPEN] — see Q1
          CODE_SIGN_STYLE: Manual
          PROVISIONING_PROFILE_SPECIFIER: "match AppStore com.example.yourapp"
          CODE_SIGN_IDENTITY: "Apple Distribution"
    dependencies:
      - package: HotwireNative

  YourAppUITests:
    type: bundle.ui-testing
    platform: iOS
    sources:
      - YourAppUITests
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.example.yourapp.UITests
      GENERATE_INFOPLIST_FILE: true
      SWIFT_VERSION: "5.0"
    dependencies:
      - target: YourApp

schemes:
  YourApp:
    build:
      targets:
        YourApp: all
    run:
      config: Debug
    test:
      config: Debug
      targets:
        - YourAppUITests
    archive:
      config: Release
```

Identical in all four and safe to copy: iOS **17.0**, `DEVELOPMENT_TEAM: PUHY9G5JNJ`,
the **jxc-org fork** of `hotwire-native-ios` on `main`, the Debug/Release config pair,
the whole `base` settings block, and the UITests target + scheme shape.

**[CORRECTED] `CODE_SIGN_IDENTITY` is `"Apple Distribution"`, not `"iPhone Distribution"`.**
`birthdaze` and `gigq` use the latter; `costco-checker` uses the former. *Reason:*
"iPhone Distribution" is Apple's legacy, platform-specific certificate name;
"Apple Distribution" is the current unified name covering iOS/macOS/tvOS/watchOS and
what Apple issues today. The newest app uses the current name. (Both still resolve for
an iOS-only app — this is a naming-currency correction, not a build fix. I did not run
a signed build to compare artefacts.)

**[CORRECTED] `bundleIdPrefix` must be a prefix of your bundle ID.** `lumberlog` has
`bundleIdPrefix: casa.coulter` against `PRODUCT_BUNDLE_IDENTIFIER: com.lumber-log.app`
— it is not a prefix of anything in that project. XcodeGen uses the prefix only to
derive bundle IDs for targets that don't set one explicitly; since every target here
sets one, lumberlog's mismatch is inert today. It is still a trap: add a target without
an explicit ID and you get `casa.coulter.*`.

**[CORRECTED] `CURRENT_PROJECT_VERSION` is a placeholder — use `2`, not a timestamp.**
`birthdaze` (`202608252003`) and `costco-checker` (`202605170007`) seed it with a
timestamp; `gigq` and `lumberlog` use `2`. This looks like a question about build
numbering and it isn't, because **nothing functional depends on the committed value**:

1. Every `beta` lane calls
   `increment_build_number(build_number: Time.now.strftime("%Y%m%d%H%M"), xcodeproj: …)`,
   which rewrites the **pbxproj** at release time. The shipped build number is always a
   fresh timestamp whatever is committed here.
2. The rake task reads `CURRENT_PROJECT_VERSION` to construct a `ClientVersion`, but the
   jbuilder template **never emits it** — the rendered `path_configuration.json` contains
   only `settings` and `rules`. (The plausible theory that a stale seed poisons the
   bundled configuration was checked and is false.)

*Reason for `2`:* a placeholder that looks like a placeholder beats one that looks like
data. A committed timestamp is permanently stale and invites someone to reason from it;
`2` cannot mislead. That is the whole argument — overturn it on better grounds if you
have them.

**Never edit `.xcodeproj` by hand.** It is generated. `cd ios && xcodegen generate`,
and commit the result — CI diffs it (see [Part 3](#part-3--ci)).

### 2.2 The five Swift files  [CONVENTION]

All four apps have exactly these, with the same names:

| file | what it does | how much is app-specific |
|---|---|---|
| `AppDelegate.swift` | Hotwire config, appearance, bridge registration | most of it |
| `SceneDelegate.swift` | navigator setup, `NavigatorDelegate` | **near-identical — copy it** |
| `<App>ViewController.swift` | the visitable view controller | small |
| `BuildConfig.swift` | where the app points | one URL |
| `UIColor+Hex.swift` | hex → `UIColor` | **byte-identical — copy it** |

`SceneDelegate.swift` differs between `birthdaze` and `costco-checker` by **zero lines**
once the app name is neutralised; `UIColor+Hex.swift` differs only in a doc-comment's
example colour. Copy both verbatim and change the type name.

`BuildConfig.swift` is the one file you must think about:

```swift
import Foundation

enum BuildConfig {
    static var baseURL: URL {
        if let override = ProcessInfo.processInfo.environment["BASE_URL"]
            ?? UserDefaults.standard.string(forKey: "baseURL"),
           let url = URL(string: override) {
            return url
        }
        return URL(string: "https://your-app.example.com")!
    }

    static var startURL: URL {
        baseURL
    }
}
```

The `BASE_URL` env override is what lets you point a simulator at `localhost` from an
Xcode scheme without editing code — keep it. `startURL` is `baseURL` in
`costco-checker` and `baseURL.appendingPathComponent("welcome")` in `birthdaze` and
`lumberlog`; that is a genuine per-app choice (does your root URL want a marketing page
or the app?), not drift.

Do **not** copy `lumberlog`'s commented-out `#if DEBUG` localhost block — the env
override above replaces it.

### 2.3 Bridge components  [CONVENTION — but absent from the template]

`costco-checker` has **no `Bridge/` directory at all**. The other three do, and the
common floor is two components:

```
ios/YourApp/Bridge/NavButtonComponent.swift
ios/YourApp/Bridge/NavMenuComponent.swift
```

Registered in `AppDelegate.configureHotwire()`:

```swift
Hotwire.registerBridgeComponents([
    NavMenuComponent.self,
    NavButtonComponent.self
])
```

**Take these from `lumberlog`** — it has exactly the two, unencumbered. (`birthdaze`
has six, `gigq` three.) This is the one place where following the template app leaves
you with less than the fleet standard.

### 2.4 `Info.plist` and entitlements  [CONVENTION]

`Info.plist` carries the scene manifest pointing at `$(PRODUCT_MODULE_NAME).SceneDelegate`,
supported orientations, `ITSAppUsesNonExemptEncryption: false`, and a `UILaunchScreen`
naming a colour asset. Copy `costco-checker`'s and adjust orientations.

`<App>.entitlements` carries associated domains for universal links and shared
web credentials:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
  <string>applinks:your-app.example.com</string>
  <string>webcredentials:your-app.example.com</string>
</array>
```

`webcredentials:` is what lets iOS offer a saved password on your web sign-in form —
worth having from day one. (`lumberlog` has no entitlements file; its `project.yml`
correctly omits `CODE_SIGN_ENTITLEMENTS` too, so it is self-consistent rather than
broken — but it has no universal links as a result.)

### 2.5 `ios/Gemfile`  [CONVENTION]

**Byte-identical across all four** (sha256 `c6b6a408515d91c3…`):

```ruby
source "https://rubygems.org"

gem "fastlane"
gem "xcpretty"
```

### 2.6 `ios/.env`  [CONVENTION]

Gitignored in all four — verified with `git check-ignore -v ios/.env`, and no app
tracks one. (Three ignore it from the root `.gitignore`; `lumberlog` uses a nested
`ios/.gitignore`. Either works; check with `git check-ignore`, not by grepping the
root file.)

It supplies exactly three variables, which are the only secrets the release path reads:

```sh
APP_STORE_CONNECT_API_KEY_ID=...
APP_STORE_CONNECT_API_KEY_ISSUER_ID=...
APP_STORE_CONNECT_API_KEY_KEY=...   # base64 of the .p8
```

---

## Part 3 — CI

Copy `costco-checker/.github/workflows/ios.yml`. Two jobs:

**`drift-path-config`** (Linux, `${{ vars.CI_RUNNER || 'homeserver-linux' }}`) —
re-renders the path configuration and fails if the committed file differs:

```sh
bundle exec rake hotwire_native:generate_ios_path_config
git diff --exit-code config/hotwire_native/path_configuration.json
```

**`build`** (`runs-on: omar`, the macOS runner) — regenerates the project, **diffs the
committed `project.pbxproj` against the generated one**, then builds and runs a launch
smoke test with `CODE_SIGNING_ALLOWED=NO`.

That pbxproj drift check is the one to be sure you copy. `lumberlog` omits it and runs
bare `xcodegen`, so a hand-edited project there would go unnoticed.

**Backfill the `ui-test` job from `birthdaze`** if your app has a flow worth testing
end-to-end — it boots Postgres, seeds a user, starts Rails, and drives the simulator
against it. It is the only one of the four with such a job.

**Path filters must name paths that exist.** `lumberlog`'s `ios.yml` triggers on
`config/hotwire_native/**`, which does not exist in that repo — the filter is inert.
List only paths you have.

**Two things CI does not cover**, so don't read green as more than it is:
- No job anywhere runs `fastlane beta`. Every CI build is `CODE_SIGNING_ALLOWED=NO`,
  so **the signing configuration is never exercised**.
- Dependabot does not scan `ios/` — see [GENER-216](https://app.plane.so/max-projects/browse/GENER-216/).
  Broader `ios/` CI coverage is [GENER-223](https://app.plane.so/max-projects/browse/GENER-223/).

**Add `ios.yml` even if you think you won't need it.** `gigq` is the only app without
one, and it is also the only app whose bundled path configuration silently fell out of
the build. Those two facts are the same fact: with no iOS job, nothing was ever in a
position to notice.

---

## Part 4 — release

Copy `costco-checker/ios/fastlane/{Appfile,Matchfile,Fastfile}`.

`Appfile` — app identifier and team:

```ruby
app_identifier("com.example.yourapp")
team_id("PUHY9G5JNJ")
```

`Fastfile` — three lanes, present in **all four** apps: `beta`, `promote`,
`promote_build`. Take `costco-checker`'s: it factors App Store Connect auth into a
`connect_api_key` helper instead of repeating the block in each lane, which the others
do. If you need App Store metadata or screenshot lanes, **backfill from `birthdaze`** —
it is the fullest (nine lanes, including `appstore_submit`).

Makefile targets, matching all four:

```make
ios-beta: ios-path-config ## Build and upload the iOS app to TestFlight
	cd ios && xcodegen generate
	cd ios && set -a && source .env && set +a && bundle exec fastlane beta

ios-promote: ## Promote latest TestFlight build to external testers (NOTE="what to test")
	cd ios && set -a && source .env && set +a && TESTFLIGHT_NOTE="$(NOTE)" bundle exec fastlane promote
```

Note `ios-beta` depends on `ios-path-config`: the bundled configuration is re-rendered
before every release build, so it can never lag the jbuilder template.

Signing setup — `Matchfile`, the certificates repo, `CODE_SIGN_STYLE` — is
[OPEN question Q1](#q1--match-or-xcode-automatic-signing). Do not copy a Matchfile
until you've read it.

---

## Open questions

**These are undecided. This document does not decide them.** Each names what actually
depends on the choice, because that is the part you need in order to pick.

### Q1 — `match`, or Xcode automatic signing?

Three apps use **`match`**: a `Matchfile` pointing at a shared certificates repo,
Release `CODE_SIGN_STYLE: Manual`, a `PROVISIONING_PROFILE_SPECIFIER` of the form
`match AppStore <bundle-id>`, and a `Fastfile` calling `match(type: "appstore")` with
explicit `export_options.provisioningProfiles`.

`lumberlog` uses **Xcode automatic signing**, and does so *coherently* — this is not a
half-finished migration. Five mutually consistent facts: no `Matchfile` (never existed
in its history — `git log --all --follow` returns nothing, positive-controlled against
`Appfile`), Release `CODE_SIGN_STYLE: Automatic`, no `PROVISIONING_PROFILE_SPECIFIER`,
no `CODE_SIGN_IDENTITY`, and a `beta` lane with no `match()` call that passes
`xcargs: "-allowProvisioningUpdates"` instead.

**What depends on the choice:** whether a release can ever run unattended. `match` is
reproducible and scriptable but needs the certificates repo, an SSH identity and a
passphrase. Automatic signing needs an interactive, signed-in Xcode and cannot run
headless. **Neither is exercised in CI today** — which is precisely why the two
approaches have coexisted for months without anyone noticing.

*A fact that belongs on the `match` side of the scale:* all four Matchfiles point at
`git@github.com:jxc/ios-certificates.git`. That URL is **correct, not stale** — the repo
exists and is private under the **pre-migration personal account**; there is no
`jxc-org/ios-certificates`. So choosing `match` means your release path depends on a
private repo *outside the org*, reached over SSH as Max personally. That is not a defect,
but it is a dependency that sits outside the boundary everything else here lives inside,
and it is part of what "unattended release" would have to solve.

### Q2 — Pin or float `jxc_rails`?

One dependency, three spellings:

| app | Gemfile |
|---|---|
| birthdaze | `tag: "v0.3.1"` |
| lumberlog | `tag: "v0.3.1"` |
| gigq | `branch: "main"` |
| costco-checker | *(no ref — tracks the default branch)* |

The gem is at **0.3.4**, so the two pinned apps are three patch releases behind.

**What depends on the choice:** whether a change to the shared gem can break an app
without a PR in that app. `~/Dev/CLAUDE.md` says cross-app coupling is fine because
"all apps move together", which argues for floating; reproducible builds and a real
CI signal argue for the tag. Note the template app uses the *loosest* form (no ref at
all), so copying it verbatim opts you into floating by default.

### Q3 — *closed*

The build-number seed (`CURRENT_PROJECT_VERSION`: timestamp vs `2`) started as an open
question and was closed by measurement rather than preference — nothing functional
depends on it. The decision and its reasoning are in §2.1, `ios/project.yml`.

---

## Known-broken, found while writing this

Not fixed here — this is a document, not a change. Each is reproducible from the
commands quoted above.

| where | what | since |
|---|---|---|
| `gigq` | `ios/GigQ/path-configuration.json` is a **dangling symlink**. Measured: absent from the generated project, absent from a built `.app`, and `AppDelegate` force-unwraps it. **Latent** — gigq has not been built for iOS yet, so this is a trap waiting on someone's first build, not damage already done | `a223a7c`, 2026-04-19 |
| `gigq` | no `ios.yml` — which is why the above was never caught | — |
| `lumberlog` | `ios.yml` triggers on `config/hotwire_native/**`, a path that does not exist there | — |
| `lumberlog` | `ios.yml` has no pbxproj-vs-`project.yml` drift check | — |
| `lumberlog` | `bundleIdPrefix: casa.coulter` is not a prefix of `com.lumber-log.app` | — |
| `costco-checker` | no `lefthook.yml`, unlike the other three | — |
| `birthdaze`, `gigq` | `CODE_SIGN_IDENTITY: "iPhone Distribution"` (legacy name) | — |

---

## What was verified, and what was not

**Verified by running it:**
- `xcodegen generate` (2.46.0) on all four apps. `costco-checker`'s committed
  `project.pbxproj` is byte-identical to the generated one. That check was also
  exercised in its **failing** state — mutating `MARKETING_VERSION` produced a
  mismatch, then restored clean — so it is not a check only ever seen pass.
- The path-configuration reference counts in the table in §1.3, with the variable
  isolated across all four apps.
- `git check-ignore -v ios/.env` in all four.
- **Simulator builds of `gigq` and `costco-checker`** from `main`
  (`xcodebuild -sdk iphonesimulator … CODE_SIGNING_ALLOWED=NO`). Both succeeded and
  produced real binaries; only `costco-checker`'s `.app` contains
  `path-configuration.json`. That pairing is what makes §1.3 a measurement rather than
  an argument.
- Staleness of every local checkout, against `gh api …/branches/main`.

**Verified by reading `FETCH_HEAD` trees**, not the local checkouts: every file,
setting, lane and workflow quoted here.

**NOT verified — do not read this document as claiming otherwise:**
- **No signed build, no device build, no TestFlight upload, no fastlane run.**
  Everything in [Part 4](#part-4--release) is read from the four apps' configuration,
  not executed. The `"Apple Distribution"` correction in §2.1 is a naming-currency
  argument; no signed artefacts were compared.
- ~~Whether `ios-certificates` exists~~ — settled during review: it exists, privately, under the personal `jxc` account. See Q1.
- **The `gigq` launch crash itself.** Four links of the chain are measured — the symlink
  dangles, the generated project has zero references, a real simulator build succeeds and
  produces a `.app` with no `path-configuration.json` (positive-controlled against
  `costco-checker`, whose build contains it), and `AppDelegate` force-unwraps that exact
  lookup. The fifth link — that this raises `nil` and traps at launch — is an inference.
  **Nobody has run the app**, and gigq has never been built for iOS outside this audit.


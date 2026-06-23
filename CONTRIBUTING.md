# Contributing to jxc_rails

## What this gem is

`jxc_rails` is two things at once:

1. **A conventions library** — short codes, persistent login, Hotwire Native gating,
   PostHog helpers, feature flags (a `Rails::Railtie`).
2. **A dependency BOM (bill of materials)** — the single source of truth for the version
   constraints of the shared runtime stack every jxc-org Rails app uses (`rails`, the
   `solid_*` trio, `propshaft`, the Hotwire gems, `devise`, `image_processing`, `pg`,
   `puma`, `bootsnap`, `thruster`). Those are declared as `add_dependency` in the gemspec.

   **Consuming apps keep these gems listed in their own Gemfile but UNVERSIONED** — the
   gems must stay top-level so `Bundler.require` loads their railties/engines (a Rails app
   will not boot if e.g. `propshaft` or `importmap-rails` is only a transitive dep), while
   jxc_rails's pins supply the versions. Apps do **not** delete the lines; they delete the
   version constraints. Dependabot in each app `ignore`s these gems so only jxc_rails moves them.

Because of (2), a version bump here can ripple into every app. The versioning rules below
exist to make that ripple legible from the version number alone.

## Versioning

`jxc_rails` follows **SemVer**, but the bump size is *derived* — it is the **maximum** of:

- **(a) jxc_rails's own public API change.** Removing/renaming a helper, concern, or
  config option is a **major**; adding one back-compatibly is a **minor**; a bugfix is a
  **patch**.
- **(b) the largest SemVer jump among the BOM dependencies** changed in this release:

  | Largest dependency jump in this release | jxc_rails bump        |
  | --------------------------------------- | --------------------- |
  | a **patch** (e.g. `8.1.3 → 8.1.4`)      | **patch** (`+0.0.1`)  |
  | a **minor** (e.g. `8.1.x → 8.2.0`)      | **minor** (`x.+1.0`)  |
  | a **major** (e.g. `3.x → 4.0`)          | **major** (`+1.0.0`)  |

Carry rules are standard SemVer: a minor bump zeroes the patch; a major zeroes minor+patch.

**The version is the max of (a) and (b).** A breaking change to jxc_rails's own API is a
major even if every dependency only moved a patch.

> **0.x note:** the gem is currently in `0.x`. By rule (b) the **first dependency *major***
> graduates it to **`1.0.0`** — a deliberate one-way door. Until then, treat the leading
> `0.` as fixed and apply the table to the minor/patch positions.

Run `bin/suggest-version` after re-locking to get a computed suggestion from the
`Gemfile.lock` diff (it only inspects, never writes). Always sanity-check it against rule
(a) — the script can't see your own API changes.

## Releasing

Releases are **git tags** — apps pin `gem "jxc_rails", github: "jxc-org/jxc_rails", tag: "vX.Y.Z"`.
We deliberately do **not** rely on the GitHub Packages registry (no per-app bundler auth to
maintain) and there is **no release workflow file** (the CI bot can't push `.github/workflows/*`).

1. Bump `lib/jxc_rails/version.rb` per the policy above (use `bin/suggest-version` as a guide).
2. Open a PR, get CI green, merge to `main`.
3. Tag and push from `main`:
   ```sh
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```
4. Bump the `tag:` in each consuming app's `Gemfile` and `bundle install` (a normal app PR).

## Dependency bumps

Dependabot in **this** repo owns the shared stack — it is the single place those gems get
version PRs. The consuming apps `ignore` the centralized gems in their own dependabot config,
so the stack moves here first, then apps adopt it by bumping the `jxc_rails` tag.

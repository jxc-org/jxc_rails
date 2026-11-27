# Changelog

## 0.4.0

### Added
- `JxcRails::Push`: a thin layer over Rails' `action_push_native` (direct APNs). `Model` concern for the app's
  `ApplicationPushDevice` (`register` upserts by token and moves it to the new owner; `unregister` is the sign-out
  hook), `ControllerConcern` for a devices controller (`create`, and `destroy` of the caller's own device only).
  Sends are skipped with one log line, never raising, while APNs credentials are not configured. Payloads and tokens
  are never logged. An APNs 410 / `BadDeviceToken` destroys the device (action_push_native's own hook).
  Adds the `action_push_native ~> 0.3.1` dependency.
- `JxcRails::TimeZone` (#38): per-user IANA time zones (`Model`, `ControllerConcern`, `jxc_time_zone_capture_tag`,
  `TimeZone.use_for`).
- `JxcRails::R2Storage` (#37): Cloudflare R2 as the standard Active Storage backend (`r2` service block, boot check,
  `jxc_rails:storage:{install,check}` tasks).
- `JxcRails::SystemSpecs`: browser specs fail instead of skipping when the browser is missing, with named,
  verified viewports; phone viewports are set over CDP where `resize_to` hits a window floor (#16-#19, #26).
- `docs/new-hotwire-app.md`: guide for creating a new Rails + Hotwire Native app (#20, #22).

### Fixed
- `jxc_time_zone_capture_tag` renders its inline script with the CSP nonce.
- A stored `time_zone` that is not a valid IANA id falls back to the configured default zone (the around_action and
  `TimeZone.use_for`) instead of raising.
- `VariantProcessorCheck` no longer crashes at boot when Active Storage is absent (#36).
- Hotwire Native UA parsing only identifies the app when the UA carries the Hotwire Native marker, so
  HeadlessChrome, SamsungBrowser and Googlebot are no longer misread (#35).

### Changed
- Ruby 3.4.12 (#34); Rails 8.1.4.1 and dependency security bumps (#7, #8, #11, #13, #14, #15, #27, #29, #33).

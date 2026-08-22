# frozen_string_literal: true

# TEMPORARY — reverted in the next commit on this branch.
#
# Evidence for GENER-71 that the CI+no-browser path is RED, not skipped. This
# example runs exactly what JxcRails::SystemSpecs.install! runs in its
# prepend_before hook, with browser absence simulated via the drill env var:
#
#   * locally (no CI env var) it SKIPS  — the old, correct behaviour
#   * in CI it RAISES and fails the build — the behaviour this ticket adds
#
# Same code path, opposite outcomes, decided only by ENV["CI"].

require "jxc_rails/system_specs"

RSpec.describe "GENER-71 RED-not-skip drill" do
  it "fails the build in CI when no browser is available, instead of skipping" do
    ENV[JxcRails::SystemSpecs::FORCE_ABSENT_ENV] = "1"

    reason = JxcRails::SystemSpecs.require_browser! # raises under CI=true
    skip(reason) if reason
  ensure
    ENV.delete(JxcRails::SystemSpecs::FORCE_ABSENT_ENV)
  end
end

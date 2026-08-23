# frozen_string_literal: true

module JxcRails
  module SystemSpecs
    # Failure mode 1: the silent-skip cliff.
    #
    # +skip "headless Chrome not available"+ is the idiomatic guard, and it is
    # a lie in CI: a skip is not a failure, so an entire app's browser coverage
    # can stop executing forever while the build stays green. Locally the skip
    # is correct (not every dev has a driver); in CI it is banned.
    #
    # Extended into {JxcRails::SystemSpecs}; constants resolve lexically from
    # there.
    module BrowserAvailability
      # Gate for a browser example. Returns nil when a browser is available,
      # a skip *reason* when running locally without one, and RAISES when
      # running in CI without one.
      def require_browser!(ci: ci?, available: browser_available?)
        return nil if available
        raise BrowserUnavailableError, missing_browser_message if ci

        "no browser available locally — install Chrome/Chromium to run this spec " \
          "(this skip is allowed only outside CI; in CI it is a hard failure)"
      end

      def browser_available?(env: ENV, path_probe: method(:executable_on_path?))
        return false if truthy?(env[FORCE_ABSENT_ENV])

        CHROME_BINARIES.any? { |bin| path_probe.call(bin, env) } || File.executable?(MACOS_CHROME)
      end

      def ci?(env: ENV)
        truthy?(env["CI"])
      end

      def missing_browser_message
        <<~MSG.strip
          [jxc_rails] No Chrome/Chromium executable found, and this is CI (CI=#{ENV.fetch("CI", nil).inspect}).

          Browser specs must FAIL, not skip, when the browser is missing. A skip is not a
          failure: it leaves CI green while zero browser coverage runs, which is exactly how
          two visual/behavioural defects shipped past a green suite (gigq#75, gigq#78,
          2026-08-22). "The runner stopped shipping Chrome" must look like a broken build,
          because it is one.

          Fix the RUNNER, not the spec:
            * ubuntu-latest ships Chrome already — check the job's `runs-on` actually resolved
              there (`Runner name:` in the job log, not the `runs-on:` expression).
            * On the self-hosted homeserver-linux image, install a browser in the job
              (browser-actions/setup-chrome) or bake it into the ARC runner image.
            * Probed on PATH: #{CHROME_BINARIES.join(", ")}
            * Probed on macOS: #{MACOS_CHROME}

          To prove this failure path on purpose (the RED-not-skip drill), set
          #{FORCE_ABSENT_ENV}=1. Do NOT set it to make a red build green.
        MSG
      end

      private

      def executable_on_path?(bin, env = ENV)
        env.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |dir|
          next false if dir.empty?

          File.executable?(File.join(dir, bin))
        end
      end

      def truthy?(value)
        !value.nil? && !value.to_s.strip.empty? && !%w[0 false no].include?(value.to_s.strip.downcase)
      end
    end
  end
end

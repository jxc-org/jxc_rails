# frozen_string_literal: true

module JxcRails
  module SystemSpecs
    # Failure mode 2: the silent viewport.
    #
    # Chrome's +--window-size+ argument is overridden (~1257px observed
    # regardless of what was asked for), so a spec that doesn't explicitly
    # resize runs at an arbitrary width and cannot see viewport-dependent bugs.
    #
    # It is worth being exact about *what* overrides it, because "Capybara
    # discards it" — the original reading — is wrong, and the real mechanism is
    # Rails, in two different places:
    #
    # 1. Before v0.3.2 the argument never reached Chrome at all. It was handed
    #    to +driven_by+'s +options:+ keyword, which Rails overwrites. That is
    #    failure mode 3; see {Helpers.chrome_arguments}.
    # 2. Even delivered, it is undone a moment later.
    #    ActionDispatch::SystemTesting::Driver#register_selenium resizes the
    #    window to +screen_size+ (default 1400x1400) as soon as the driver
    #    exists. Measured: +--window-size=390,844+ reaches Chrome's command
    #    line and the session still reports innerWidth=1400.
    #
    # So the advice is unchanged and the reason is now known: viewports are set
    # with +resize_to+, from a named set, and *verified* against the browser's
    # own reported width — trusting the resize is what produced the bug in the
    # first place.
    #
    # Extended into {JxcRails::SystemSpecs}; constants resolve lexically from
    # there.
    module Viewports
      def viewport(name)
        VIEWPORTS.fetch(name&.to_sym) do
          raise ViewportError, "[jxc_rails] unknown viewport #{name.inspect}; known: #{VIEWPORTS.keys.join(", ")}"
        end
      end

      def default_viewport
        JxcRails.config.system_specs.default_viewport
      end

      # Resize +page+ to a named viewport and prove it took. Returns the
      # Viewport.
      def apply_viewport!(page, name = default_viewport)
        target = viewport(name)
        window = window_for(page)
        if window.nil?
          raise ViewportError, "[jxc_rails] driver exposes no resizable window; is this spec driven_by " \
                               ":rack_test? Browser viewports need a real browser."
        end

        window.resize_to(target.width, target.height)
        drift = viewport_drift(expected: target, actual_width: measured_width(page))
        raise ViewportError, drift if drift

        self.applied_viewport = target
      end

      # Pure drift check, injectable for tests. Returns a message or nil.
      # Width only: it is what CSS breakpoints key off, while innerHeight varies
      # with browser chrome and headless mode.
      def viewport_drift(expected:, actual_width:, tolerance: WIDTH_TOLERANCE)
        return nil if actual_width.nil? # not a real browser session; nothing to measure
        return nil if (expected.width - actual_width).abs <= tolerance

        "[jxc_rails] viewport did not take: asked for #{expected}, browser reports " \
          "window.innerWidth=#{actual_width}. Chrome's --window-size arg is overridden by the " \
          "screen_size resize Rails does when it builds the driver — set viewports with " \
          "resize_to (use_viewport/:viewport), and make sure no later driven_by call re-created " \
          "the driver after the resize."
      end

      # After-example lint: fails a browser example that never declared a
      # viewport, or whose viewport drifted after it was applied (e.g. a later
      # driven_by rebuilt the driver at its default width). Message or nil.
      def viewport_guard_problem(page)
        return nil if window_for(page).nil? # rack_test / no browser: viewport is meaningless

        target = applied_viewport
        return undeclared_viewport_message if target.nil?

        viewport_drift(expected: target, actual_width: measured_width(page))
      end

      def undeclared_viewport_message
        "[jxc_rails] browser example ran without a declared viewport, so it ran at whatever " \
          "width the driver defaulted to (~1257px observed) — viewport-dependent bugs are " \
          "invisible to it. Call drive_headless_chrome!(viewport: :desktop) or " \
          "use_viewport(:phone_new) — named viewports: #{VIEWPORTS.keys.join(", ")}."
      end

      # Per-example state. RSpec runs examples serially per thread.
      def applied_viewport
        Thread.current[:jxc_rails_applied_viewport]
      end

      def applied_viewport=(viewport)
        Thread.current[:jxc_rails_applied_viewport] = viewport
      end

      def reset_example_state!
        self.applied_viewport = nil
      end

      private

      def window_for(page)
        driver  = page.respond_to?(:driver) ? page.driver : nil
        browser = driver.respond_to?(:browser) ? driver.browser : nil
        manage  = browser.respond_to?(:manage) ? browser.manage : nil
        window  = manage.respond_to?(:window) ? manage.window : nil
        window if window.respond_to?(:resize_to)
      end

      # The rendered viewport width — what media queries actually see.
      def measured_width(page)
        return nil unless page.respond_to?(:evaluate_script)

        page.evaluate_script("window.innerWidth")&.to_i
      end
    end
  end
end

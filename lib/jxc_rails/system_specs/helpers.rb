# frozen_string_literal: true

module JxcRails
  module SystemSpecs
    # Mixed into +type: :system+ example groups by
    # {JxcRails::SystemSpecs.install!}. Everything here is a thin, testable
    # shim over the module functions — the decision logic lives there.
    module Helpers
      # One-line replacement for the eight-line driven_by + skip preamble every
      # browser spec was copy-pasting. Drives headless Chrome and immediately
      # pins a *named* viewport, so a spec can't silently inherit the driver's
      # arbitrary default width.
      #
      #   before { drive_headless_chrome!(viewport: :phone_new) }
      #
      # The viewport is applied with resize_to AFTER the driver exists — passing
      # --window-size here would be discarded by Capybara's setup (that is
      # failure mode 2; see JxcRails::SystemSpecs).
      def drive_headless_chrome!(viewport: JxcRails::SystemSpecs.default_viewport,
                                 args: JxcRails.config.system_specs.browser_args)
        driven_by(:selenium, **JxcRails::SystemSpecs::Helpers.driver_options(args))
        use_viewport(viewport)
      end

      # Resize the current session to a named viewport, verifying it took.
      def use_viewport(name = JxcRails::SystemSpecs.default_viewport)
        JxcRails::SystemSpecs.apply_viewport!(page, name)
      end

      # Dimensions of a named viewport, for specs that need to assert against
      # them (e.g. expected image widths).
      def viewport(name)
        JxcRails::SystemSpecs.viewport(name)
      end

      # Builds the driven_by keyword args. Selenium is a host-app dependency,
      # not a gem dependency, so fall back to bare :headless_chrome when the
      # Options class isn't loaded rather than blowing up at require time.
      def self.driver_options(args)
        return { using: :headless_chrome } unless defined?(::Selenium::WebDriver::Chrome::Options)

        {
          using: :headless_chrome,
          options: { options: ::Selenium::WebDriver::Chrome::Options.new(args: Array(args)) }
        }
      end
    end
  end
end

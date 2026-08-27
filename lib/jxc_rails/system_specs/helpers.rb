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
      #
      # The Chrome args go through driven_by's *block*, not its +options:+
      # keyword — see {.chrome_arguments} for why the keyword is a trap.
      def drive_headless_chrome!(viewport: JxcRails::SystemSpecs.default_viewport,
                                 args: JxcRails.config.system_specs.browser_args)
        driven_by(:selenium, **JxcRails::SystemSpecs::Helpers.driver_options,
                  &JxcRails::SystemSpecs::Helpers.chrome_arguments(args))
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

      # The driven_by keyword args. Deliberately carries no +options:+ — see
      # {.chrome_arguments}.
      def self.driver_options
        { using: :headless_chrome }
      end

      # Failure mode 3: the silent Chrome argument.
      #
      # +driven_by(..., options: { options: Chrome::Options.new(args:) })+ reads
      # like it forwards those args, and silently does not:
      # ActionDispatch::SystemTesting::Driver#browser_options is
      #
      #   @options.merge(options: @browser.options)
      #
      # — the caller's +:options+ is *overwritten* by Rails' own freshly built
      # Chrome::Options. Rails' documented seam is the block, which yields that
      # very object, so arguments added here are the ones Chrome launches with.
      #
      # This is not cosmetic: it is how +--disable-dev-shm-usage+ went missing
      # on the self-hosted ARC runners, where /dev/shm is 64MB, and every
      # browser spec past the first handful died with "tab crashed". A roomy
      # /dev/shm (ubuntu-latest, a dev laptop) hides it completely.
      def self.chrome_arguments(args = JxcRails.config.system_specs.browser_args)
        list = Array(args)

        proc { |options| list.each { |arg| options.add_argument(arg) } }
      end
    end
  end
end

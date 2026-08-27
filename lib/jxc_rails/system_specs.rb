# frozen_string_literal: true

module JxcRails
  # Guards against the "CI is green but the browser coverage never ran, or ran
  # at the wrong size" class of bug — two ways a passing suite can be a lie.
  # Each is implemented in its own submodule and documented there:
  #
  # 1. {BrowserAvailability} — the *silent-skip cliff*. `skip "Chrome not
  #    available"` keeps CI green while zero browser specs execute. jxc-org's
  #    browser specs run today only because the org's +CI_RUNNER+ variable
  #    happens to resolve to +ubuntu-latest+ (which ships Chrome); flipping the
  #    fleet back to the self-hosted +homeserver-linux+ image would zero all
  #    browser coverage with nothing red anywhere. In CI, missing browser now
  #    raises.
  #
  # 2. {Viewports} — the *silent viewport*. Chrome's +--window-size+ argument
  #    is overridden, not honoured (~1257px observed regardless), so specs that
  #    don't explicitly resize can't see viewport-dependent bugs. Viewports come
  #    from a named set, are applied with +resize_to+, and are verified against
  #    the browser's own reported width.
  #
  # 3. {Helpers.chrome_arguments} — the *silent Chrome argument*. +driven_by+'s
  #    +options:+ keyword looks like it forwards Chrome args and does not:
  #    Rails overwrites it with its own Chrome::Options. Args go through
  #    driven_by's block instead. This is how +--disable-dev-shm-usage+ went
  #    missing on the self-hosted ARC runners (64MB /dev/shm) and every browser
  #    spec past the first handful died with "tab crashed", while ubuntu-latest
  #    and dev laptops — roomy /dev/shm — stayed green.
  #
  # Wire it up once per app, in +rails_helper.rb+:
  #
  #   JxcRails::SystemSpecs.install!(RSpec.configuration)
  #
  # and in each browser spec's +before+:
  #
  #   drive_headless_chrome!(viewport: :phone_new)
  module SystemSpecs
    # Raised in CI when no browser is available. Deliberately not a skip.
    class BrowserUnavailableError < JxcRails::Error; end
    # Raised when a viewport can't be applied, or didn't take.
    class ViewportError < JxcRails::Error; end

    Viewport = Struct.new(:name, :width, :height) do
      def to_s
        "#{name} (#{width}x#{height})"
      end
    end

    # Named viewports for the fleet. Widths are what matter: they drive the CSS
    # breakpoints the shipped UI is built against.
    VIEWPORTS = {
      phone_old: Viewport.new(:phone_old, 390, 844).freeze,
      phone_new: Viewport.new(:phone_new, 402, 874).freeze,
      desktop: Viewport.new(:desktop, 1280, 900).freeze
    }.freeze

    # Executables that count as "a browser is installed", in probe order.
    CHROME_BINARIES = %w[google-chrome-stable google-chrome chromium chromium-browser].freeze
    MACOS_CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

    # Set to simulate browser absence (the RED-not-skip drill) without
    # uninstalling anything.
    FORCE_ABSENT_ENV = "JXC_RAILS_FORCE_BROWSER_ABSENT"

    # A vertical scrollbar eats real estate off window.innerWidth, and its width
    # is platform/Chrome-version dependent (0 for overlay scrollbars, ~15px for
    # classic). Anything beyond this is drift, not a scrollbar.
    WIDTH_TOLERANCE = 20

    require_relative "system_specs/browser_availability"
    require_relative "system_specs/viewports"

    extend BrowserAvailability
    extend Viewports

    class << self
      # Installs the browser gate, the helpers, and the viewport guard for all
      # +type: :system+ examples.
      def install!(rspec_config, type: :system)
        require_relative "system_specs/helpers"

        rspec_config.include(Helpers, type: type)

        rspec_config.prepend_before(:each, type: type) do
          JxcRails::SystemSpecs.reset_example_state!
          reason = JxcRails::SystemSpecs.require_browser!
          skip(reason) if reason
        end

        rspec_config.after(:each, type: type) do |example|
          # Don't mask a real failure with the guard's own complaint.
          problem = example.exception ? nil : JxcRails::SystemSpecs.viewport_guard_problem(page)
          raise JxcRails::SystemSpecs::ViewportError, problem if problem
        end
      end
    end
  end
end

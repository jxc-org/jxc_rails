# frozen_string_literal: true

# Stand-ins for Capybara sessions, so the system-spec guards can be unit-tested
# without Capybara, Selenium, or an actual browser — the gem depends on none of
# them, and the whole point of these guards is that they must work on a runner
# where the browser is missing.
module FakeCapybara
  # Records every resize_to call, and reports back whatever innerWidth the
  # session was told to report — which is how "the resize silently didn't take"
  # is simulated.
  class Window
    attr_reader :resizes

    def initialize(session)
      @session = session
      @resizes = []
    end

    def resize_to(width, height)
      @resizes << [width, height]
      @session.reported_width = [width, @session.min_window_width].max unless @session.ignore_resize
    end
  end

  # A session backed by a real browser: page.driver.browser.manage.window
  # resolves, and evaluate_script answers. +min_window_width+ simulates an OS
  # window floor (macOS headless Chrome: 500px) — resize_to below it clamps.
  class BrowserSession
    attr_accessor :reported_width, :ignore_resize
    attr_reader :min_window_width, :window

    def initialize(reported_width: nil, ignore_resize: false, min_window_width: 0)
      @reported_width   = reported_width
      @ignore_resize    = ignore_resize
      @min_window_width = min_window_width
      @window           = Window.new(self)
    end

    def resizes
      @window.resizes
    end

    def driver
      self
    end

    def browser
      self
    end

    def manage
      self
    end

    def evaluate_script(script)
      raise ArgumentError, "unexpected script: #{script}" unless script == "window.innerWidth"

      @reported_width
    end
  end

  # A Chromium session: also answers execute_cdp. Emulation.setDeviceMetricsOverride
  # sets the layout viewport directly, so it is not subject to the window floor —
  # unless +ignore_cdp+, which simulates the override silently not taking.
  class CdpBrowserSession < BrowserSession
    # Raised by +raise_cdp+. Stands in for the driver-level errors a real
    # Selenium session throws when it answers execute_cdp but the command does
    # not reach a CDP endpoint — a remote grid without one, say. The gem never
    # loads Selenium, so the real class cannot be referenced here.
    class CdpUnavailable < StandardError; end

    attr_reader :cdp_calls

    def initialize(ignore_cdp: false, raise_cdp: false, **)
      super(**)
      @ignore_cdp = ignore_cdp
      @raise_cdp  = raise_cdp
      @cdp_calls  = []
    end

    def execute_cdp(cmd, **params)
      @cdp_calls << [cmd, params]
      raise CdpUnavailable, "no CDP endpoint" if @raise_cdp

      self.reported_width = params[:width] if cmd == "Emulation.setDeviceMetricsOverride" && !@ignore_cdp
      {}
    end
  end

  # A rack_test-style session. It answers none of
  # driver/browser/manage/window, which is exactly how the guards recognise
  # "not a browser session, so viewports are meaningless here" — the one method
  # it does define exists only to prove the object is otherwise usable.
  class RackTestSession
    def html
      "<html><body>rack_test</body></html>"
    end
  end

  # Stands in for the Selenium::WebDriver::Chrome::Options object Rails yields
  # to the driven_by block — it records the arguments added to it.
  class ChromeOptions
    attr_reader :args

    def initialize
      @args = []
    end

    def add_argument(arg)
      @args << arg
    end
  end
end

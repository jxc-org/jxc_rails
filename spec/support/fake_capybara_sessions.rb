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
      @session.reported_width = width unless @session.ignore_resize
    end
  end

  # A session backed by a real browser: page.driver.browser.manage.window
  # resolves, and evaluate_script answers.
  class BrowserSession
    attr_accessor :reported_width, :ignore_resize

    def initialize(reported_width: nil, ignore_resize: false)
      @reported_width = reported_width
      @ignore_resize  = ignore_resize
      @window         = Window.new(self)
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

    attr_reader :window

    def evaluate_script(script)
      raise ArgumentError, "unexpected script: #{script}" unless script == "window.innerWidth"

      @reported_width
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
end

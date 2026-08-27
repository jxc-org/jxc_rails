# frozen_string_literal: true

require "jxc_rails/system_specs"
require "jxc_rails/system_specs/helpers"
require_relative "../support/fake_capybara_sessions"

RSpec.describe JxcRails::SystemSpecs do
  before { JxcRails::SystemSpecs.reset_example_state! }
  after  { JxcRails::SystemSpecs.reset_example_state! }

  describe ".require_browser!" do
    it "RAISES in CI when no browser is available — never skips" do
      expect { described_class.require_browser!(ci: true, available: false) }
        .to raise_error(JxcRails::SystemSpecs::BrowserUnavailableError, /must FAIL, not skip/)
    end

    it "explains what to install and why the skip is forbidden" do
      message = begin
        described_class.require_browser!(ci: true, available: false)
      rescue JxcRails::SystemSpecs::BrowserUnavailableError => e
        e.message
      end

      expect(message).to include("google-chrome-stable")           # what to install
      expect(message).to include("homeserver-linux")               # where it's missing
      expect(message).to include("zero browser coverage")          # why skipping is banned
      expect(message).to include("JXC_RAILS_FORCE_BROWSER_ABSENT") # how to drill it
    end

    it "returns a skip reason locally (not every dev has a driver installed)" do
      reason = described_class.require_browser!(ci: false, available: false)

      expect(reason).to include("no browser available locally")
      expect(reason).to include("in CI it is a hard failure")
    end

    it "returns nil when a browser is available, in CI or out" do
      expect(described_class.require_browser!(ci: true, available: true)).to be_nil
      expect(described_class.require_browser!(ci: false, available: true)).to be_nil
    end
  end

  describe ".browser_available?" do
    # Simulates a PATH containing the named binaries.
    def path_with(*binaries)
      ->(bin, _env) { binaries.include?(bin) }
    end

    it "is true when a known Chrome binary is on PATH" do
      expect(described_class.browser_available?(env: {}, path_probe: path_with("chromium"))).to be(true)
    end

    it "is false when nothing on PATH matches (and no macOS Chrome.app)" do
      allow(File).to receive(:executable?).with(described_class::MACOS_CHROME).and_return(false)

      expect(described_class.browser_available?(env: {}, path_probe: path_with)).to be(false)
    end

    it "reports absence when the drill flag is set, even with Chrome installed" do
      env = { described_class::FORCE_ABSENT_ENV => "1" }

      expect(described_class.browser_available?(env: env, path_probe: path_with("google-chrome"))).to be(false)
    end
  end

  describe ".ci?" do
    it "reads CI, treating the shell's falsey spellings as not-CI" do
      expect(described_class.ci?(env: { "CI" => "true" })).to be(true)
      expect(described_class.ci?(env: { "CI" => "1" })).to be(true)
      expect(described_class.ci?(env: { "CI" => "false" })).to be(false)
      expect(described_class.ci?(env: { "CI" => "" })).to be(false)
      expect(described_class.ci?(env: {})).to be(false)
    end
  end

  describe ".viewport" do
    it "exposes the fleet's named viewports at exact dimensions" do
      expect(described_class.viewport(:phone_old).to_a).to eq([:phone_old, 390, 844])
      expect(described_class.viewport(:phone_new).to_a).to eq([:phone_new, 402, 874])
      expect(described_class.viewport(:desktop).to_a).to eq([:desktop, 1280, 900])
    end

    it "accepts a string name" do
      expect(described_class.viewport("desktop").width).to eq(1280)
    end

    it "raises on an unknown name rather than silently picking a default" do
      expect { described_class.viewport(:tablet) }
        .to raise_error(JxcRails::SystemSpecs::ViewportError, /unknown viewport :tablet/)
    end
  end

  describe ".apply_viewport!" do
    it "resizes through resize_to with the viewport's exact dimensions" do
      page = FakeCapybara::BrowserSession.new

      described_class.apply_viewport!(page, :phone_new)

      expect(page.resizes).to eq([[402, 874]])
    end

    it "records the applied viewport so the after-hook guard can verify it" do
      page = FakeCapybara::BrowserSession.new

      described_class.apply_viewport!(page, :phone_old)

      expect(described_class.applied_viewport.name).to eq(:phone_old)
      expect(described_class.applied_viewport.width).to eq(390)
    end

    it "uses the configured default viewport when none is named" do
      page = FakeCapybara::BrowserSession.new

      described_class.apply_viewport!(page)

      expect(page.resizes).to eq([[1280, 900]])
    end

    it "raises when the resize silently doesn't take (the --window-size failure mode)" do
      page = FakeCapybara::BrowserSession.new(reported_width: 1257, ignore_resize: true)

      expect { described_class.apply_viewport!(page, :phone_new) }
        .to raise_error(JxcRails::SystemSpecs::ViewportError, /viewport did not take.*innerWidth=1257/m)
    end

    it "raises when the session has no resizable window (driven_by :rack_test)" do
      expect { described_class.apply_viewport!(FakeCapybara::RackTestSession.new, :desktop) }
        .to raise_error(JxcRails::SystemSpecs::ViewportError, /no resizable window/)
    end
  end

  describe ".viewport_drift" do
    let(:desktop) { described_class.viewport(:desktop) }

    it "tolerates a scrollbar's worth of shortfall" do
      expect(described_class.viewport_drift(expected: desktop, actual_width: 1265)).to be_nil
    end

    it "flags anything beyond the scrollbar tolerance" do
      expect(described_class.viewport_drift(expected: desktop, actual_width: 1257))
        .to include("asked for desktop (1280x900)", "innerWidth=1257")
    end

    it "stays quiet when the width can't be measured at all" do
      expect(described_class.viewport_drift(expected: desktop, actual_width: nil)).to be_nil
    end
  end

  describe ".viewport_guard_problem" do
    it "fails a browser example that never declared a viewport" do
      problem = described_class.viewport_guard_problem(FakeCapybara::BrowserSession.new(reported_width: 1257))

      expect(problem).to include("without a declared viewport", "~1257px")
    end

    it "passes a browser example that declared one and kept it" do
      page = FakeCapybara::BrowserSession.new
      described_class.apply_viewport!(page, :desktop)

      expect(described_class.viewport_guard_problem(page)).to be_nil
    end

    it "catches a viewport that drifted after it was applied (a later driven_by)" do
      page = FakeCapybara::BrowserSession.new
      described_class.apply_viewport!(page, :phone_new)
      page.reported_width = 1257 # driver rebuilt underneath us

      expect(described_class.viewport_guard_problem(page)).to include("viewport did not take")
    end

    it "ignores non-browser sessions, where a viewport is meaningless" do
      expect(described_class.viewport_guard_problem(FakeCapybara::RackTestSession.new)).to be_nil
    end
  end

  describe JxcRails::SystemSpecs::Helpers do
    # Collects what .chrome_arguments adds, standing in for the Chrome::Options
    # object Rails yields to the driven_by block.
    def arguments_added_by(applier)
      recorder = FakeCapybara::ChromeOptions.new
      applier.call(recorder)
      recorder.args
    end

    describe ".driver_options" do
      it "carries no :options key — driven_by overwrites it, so args sent that way vanish" do
        expect(described_class.driver_options).to eq(using: :headless_chrome)
      end
    end

    describe ".chrome_arguments" do
      it "adds every configured arg to the options object Rails yields" do
        expect(arguments_added_by(described_class.chrome_arguments)).to include("--no-sandbox", "--disable-dev-shm-usage")
      end

      it "accepts an explicit list, and tolerates a bare string" do
        expect(arguments_added_by(described_class.chrome_arguments("--disable-gpu"))).to eq(["--disable-gpu"])
      end

      it "never passes --window-size, which Capybara's driver setup discards" do
        expect(arguments_added_by(described_class.chrome_arguments)).not_to include(a_string_matching(/window-size/))
      end
    end
  end

  describe "configuration" do
    after { JxcRails.reset_configuration! }

    it "defaults to a deterministic named viewport, not the driver's arbitrary width" do
      expect(JxcRails.config.system_specs.default_viewport).to eq(:desktop)
    end

    it "lets an app change the default viewport for its whole suite" do
      JxcRails.configure { |c| c.system_specs.default_viewport = :phone_new }
      page = FakeCapybara::BrowserSession.new

      described_class.apply_viewport!(page)

      expect(page.resizes).to eq([[402, 874]])
    end

    it "ships Chrome args without --window-size" do
      expect(JxcRails.config.system_specs.browser_args).not_to include(a_string_matching(/window-size/))
    end
  end
end

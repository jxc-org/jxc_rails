# frozen_string_literal: true

require "capybara"
require "selenium/webdriver"
require "action_dispatch"
require "action_dispatch/system_test_case"
require "jxc_rails/system_specs"
require "jxc_rails/system_specs/helpers"

# Failure mode 3: the silent Chrome argument.
#
# +driven_by+ looks like it forwards +options:+ to the browser. It does not:
# ActionDispatch::SystemTesting::Driver#browser_options is
#
#   @options.merge(options: @browser.options)
#
# so any +options:+ the caller passed is *overwritten* by Rails' own freshly
# built Chrome::Options. Arguments handed in that way never reach Chrome, and
# nothing anywhere says so — the suite goes green on a roomy runner and dies
# with "tab crashed" on a container whose /dev/shm is 64MB.
#
# These examples assert on the arguments Rails actually hands to Capybara, one
# step before the browser launches, so the plumbing is checked rather than the
# shape of our own hash. No browser is started.
RSpec.describe "Chrome arguments" do
  # Stands in for the rspec-rails system example group: records the driven_by
  # call (keywords AND block) so it can be replayed through the real Rails
  # driver.
  class RecordingExample # rubocop:disable Lint/ConstantDefinitionInBlock
    include JxcRails::SystemSpecs::Helpers

    attr_reader :driver, :keywords, :block

    def driven_by(driver, **keywords, &block)
      @driver = driver
      @keywords = keywords
      @block = block
    end

    # There is no browser here, so the viewport half of the helper is a no-op.
    def use_viewport(_name = nil); end
  end

  # The arguments Rails will pass to Capybara::Selenium::Driver, i.e. the ones
  # Chrome is actually launched with.
  def chrome_arguments_for(example)
    driver = ActionDispatch::SystemTestCase.driven_by(example.driver, **example.keywords, &example.block)
    driver.send(:register)
    driver.send(:browser_options).fetch(:options).args
  end

  def recorded(**kwargs)
    RecordingExample.new.tap { |example| example.drive_headless_chrome!(**kwargs) }
  end

  before do
    # Rails eagerly resolves the chromedriver binary when the driver is built.
    # Locating a driver is not what's under test, and CI shouldn't need to.
    allow_any_instance_of(ActionDispatch::SystemTesting::Browser).to receive(:preload)
  end

  it "delivers the configured browser args all the way to Chrome's command line" do
    args = chrome_arguments_for(recorded)

    expect(args).to include("--no-sandbox", "--disable-dev-shm-usage")
  end

  it "delivers args a spec passes explicitly" do
    args = chrome_arguments_for(recorded(args: %w[--disable-gpu]))

    expect(args).to include("--disable-gpu")
  end

  it "keeps the arguments Rails adds for headless Chrome" do
    args = chrome_arguments_for(recorded)

    expect(args).to include("--headless")
  end

  it "still never asks for --window-size, which Capybara's setup discards" do
    expect(chrome_arguments_for(recorded)).not_to include(a_string_matching(/window-size/))
  end
end

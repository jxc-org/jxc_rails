# frozen_string_literal: true

require "spec_helper"
require "action_view"
require "jxc_rails/posthog/helper"

RSpec.describe JxcRails::Posthog::Helper do
  let(:view) do
    Class.new do
      include ActionView::Helpers::TagHelper
      include JxcRails::Posthog::Helper
      attr_accessor :output_buffer, :native

      def turbo_native_app? = native
    end.new
  end

  describe "#posthog_native_register_tags" do
    it "returns a script tag registering app_source when native" do
      view.native = true
      html = view.posthog_native_register_tags
      expect(html).to include("posthog.register")
      expect(html).to include("app_source")
      expect(html).to include("ios_webview")
      expect(html).to include("<script>")
    end

    it "registers app_source as 'web' when not native" do
      view.native = false
      html = view.posthog_native_register_tags
      expect(html).to include("app_source: 'web'")
      expect(html).not_to include("ios_webview")
    end
  end

  describe "#posthog_snippet" do
    it "returns nil when api_key is blank" do
      expect(view.posthog_snippet(api_key: nil)).to be_nil
      expect(view.posthog_snippet(api_key: "")).to be_nil
    end

    it "renders the loader and posthog.init with the proxy host by default" do
      html = view.posthog_snippet(api_key: "phc_test")
      expect(html).to start_with("<script>")
      expect(html).to include("posthog.init(")
      expect(html).to include("\"phc_test\"")
      expect(html).to include('"api_host":"https://abc.johnxcoulter.com"')
      expect(html).to include('"ui_host":"https://us.posthog.com"')
    end

    it "honors POSTHOG_API_HOST env override" do
      ClimateControl.modify(POSTHOG_API_HOST: "https://other.example.com") do
        html = view.posthog_snippet(api_key: "phc_test")
        expect(html).to include('"api_host":"https://other.example.com"')
      end
    rescue NameError
      # ClimateControl not available — fall back to ENV manipulation
      original = ENV.fetch("POSTHOG_API_HOST", nil)
      begin
        ENV["POSTHOG_API_HOST"] = "https://other.example.com"
        html = view.posthog_snippet(api_key: "phc_test")
        expect(html).to include('"api_host":"https://other.example.com"')
      ensure
        ENV["POSTHOG_API_HOST"] = original
      end
    end

    it "merges extra options into the init call" do
      html = view.posthog_snippet(
        api_key: "phc_test",
        autocapture: false,
        capture_pageview: false,
        property_denylist: ["$ip"]
      )
      expect(html).to include('"autocapture":false')
      expect(html).to include('"capture_pageview":false')
      expect(html).to include('"property_denylist":["$ip"]')
    end

    it "escapes </script> sequences in encoded values" do
      html = view.posthog_snippet(api_key: "phc_</script>")
      expect(html).not_to include("</script></script>")
      expect(html).to include('"phc_<\\/script>"')
    end
  end
end

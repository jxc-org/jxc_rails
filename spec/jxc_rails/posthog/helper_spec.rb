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

    it "returns an empty string when not native" do
      view.native = false
      expect(view.posthog_native_register_tags).to eq("")
    end
  end
end

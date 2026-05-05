# frozen_string_literal: true

require "spec_helper"
require "jxc_rails/posthog/config"

RSpec.describe JxcRails::Posthog::Config do
  describe ".build_client" do
    it "returns nil when api_key is blank" do
      expect(described_class.build_client(api_key: nil)).to be_nil
      expect(described_class.build_client(api_key: "")).to be_nil
    end

    it "constructs a PostHog::Client with the proxy host by default" do
      stub_const("PostHog", Module.new)
      client_class = Class.new do
        attr_reader :options

        def initialize(**options) = @options = options
      end
      stub_const("PostHog::Client", client_class)

      client = described_class.build_client(api_key: "phc_test")

      expect(client).to be_a(client_class)
      expect(client.options[:api_key]).to eq("phc_test")
      expect(client.options[:host]).to eq("https://abc.johnxcoulter.com")
      expect(client.options[:feature_flags_polling_interval]).to eq(600)
      expect(client.options[:on_error]).to be_a(Proc)
    end

    it "honors POSTHOG_API_HOST env override" do
      stub_const("PostHog", Module.new)
      client_class = Class.new do
        attr_reader :options

        def initialize(**options) = @options = options
      end
      stub_const("PostHog::Client", client_class)

      original = ENV.fetch("POSTHOG_API_HOST", nil)
      begin
        ENV["POSTHOG_API_HOST"] = "https://other.example.com"
        client = described_class.build_client(api_key: "phc_test")
        expect(client.options[:host]).to eq("https://other.example.com")
      ensure
        ENV["POSTHOG_API_HOST"] = original
      end
    end

    it "passes through caller-supplied host" do
      stub_const("PostHog", Module.new)
      client_class = Class.new do
        attr_reader :options

        def initialize(**options) = @options = options
      end
      stub_const("PostHog::Client", client_class)

      client = described_class.build_client(api_key: "phc_test", host: "https://custom.example.com")
      expect(client.options[:host]).to eq("https://custom.example.com")
    end
  end
end

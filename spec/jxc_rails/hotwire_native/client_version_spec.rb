# frozen_string_literal: true

require "spec_helper"
require "ostruct"

RSpec.describe JxcRails::HotwireNative::ClientVersion do
  def request_with(headers: {}, user_agent: "")
    double_headers = Class.new do
      def initialize(h) = @h = h
      def [](k) = @h[k]
    end.new(headers)
    OpenStruct.new(headers: double_headers, user_agent: user_agent)
  end

  describe ".from_request" do
    it "prefers X-App-* headers over User-Agent" do
      req = request_with(
        headers: { "X-App-Name" => "Birthdaze", "X-App-Version" => "2.1.0", "X-App-Build" => "42" },
        user_agent: "irrelevant/9.9.9"
      )
      client = described_class.from_request(req)
      expect(client.app_name).to eq("Birthdaze")
      expect(client.version.to_s).to eq("2.1.0")
      expect(client.build).to eq(42)
    end

    it "falls back to User-Agent regex when headers are missing" do
      req = request_with(user_agent: "Mozilla/5.0 Birthdaze/2.1.0 (build 42) AppleWebKit/537")
      client = described_class.from_request(req)
      expect(client.app_name).to eq("Birthdaze")
      expect(client.version.to_s).to eq("2.1.0")
      expect(client.build).to eq(42)
    end

    it "returns nil when neither headers nor UA identify an app" do
      expect(described_class.from_request(request_with)).to be_nil
    end
  end

  describe "comparisons" do
    subject(:client) { described_class.new(app_name: "App", version: "2.1.0") }

    it { expect(client.at_least?("2.0")).to be true }
    it { expect(client.at_least?("2.1.0")).to be true }
    it { expect(client.at_least?("2.2")).to be false }
    it { expect(client.below?("2.2")).to be true }
    it { expect(client.below?("2.0")).to be false }
    it { expect(client.in_range?(min: "2.0", max: "3.0")).to be true }
    it { expect(client.in_range?(max: "2.0")).to be false }
    it { expect(client.in_range?(min: "3.0")).to be false }
  end
end

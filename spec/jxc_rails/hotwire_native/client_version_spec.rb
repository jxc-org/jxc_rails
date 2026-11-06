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
      req = request_with(user_agent: "Mozilla/5.0 Birthdaze/2.1.0 (build 42) AppleWebKit/537 Hotwire Native iOS; Turbo Native iOS;")
      client = described_class.from_request(req)
      expect(client.app_name).to eq("Birthdaze")
      expect(client.version.to_s).to eq("2.1.0")
      expect(client.build).to eq(42)
    end

    it "returns nil when neither headers nor UA identify an app" do
      expect(described_class.from_request(request_with)).to be_nil
    end

    # rubocop:disable Layout/LineLength
    non_app_uas = {
      "HeadlessChrome" => "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/156.0.0.0 Safari/537.36",
      "SamsungBrowser" => "Mozilla/5.0 (Linux; Android 14; SM-S921B) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/25.0 Chrome/121.0.0.0 Mobile Safari/537.36",
      "Googlebot" => "Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; Googlebot/2.1; +http://www.google.com/bot.html) Chrome/130.0.0.0 Safari/537.36",
      "bingbot" => "Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm) Chrome/116.0.1938.76 Safari/537.36",
      "desktop Chrome" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"
    }
    # rubocop:enable Layout/LineLength

    non_app_uas.each do |name, ua|
      it "returns nil for a #{name} User-Agent without the Hotwire Native marker" do
        expect(described_class.from_request(request_with(user_agent: ua))).to be_nil
      end
    end

    app_ua = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) " \
             "Birthdaze/1.6.0%s Hotwire Native iOS; Turbo Native iOS;"

    it "parses the Hotwire Native iOS app User-Agent with a build" do
      ua = "#{format(app_ua, " (build 42)")} bridge-components: [search form]"
      client = described_class.from_request(request_with(user_agent: ua))
      expect([client.app_name, client.version.to_s, client.build]).to eq(["Birthdaze", "1.6.0", 42])
    end

    it "parses the Hotwire Native iOS app User-Agent without a build" do
      client = described_class.from_request(request_with(user_agent: format(app_ua, "")))
      expect([client.app_name, client.version.to_s, client.build]).to eq(["Birthdaze", "1.6.0", nil])
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

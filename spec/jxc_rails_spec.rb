# frozen_string_literal: true

require "spec_helper"

RSpec.describe JxcRails do
  it "has a version number" do
    expect(JxcRails::VERSION).not_to be nil
  end

  describe ".configure" do
    after { described_class.reset_configuration! }

    it "yields the configuration" do
      described_class.configure do |c|
        c.hotwire_native.app_name        = "TestApp"
        c.hotwire_native.min_app_version = "1.0"
        c.short_code.default_length      = 10
      end

      expect(described_class.configuration.hotwire_native.app_name).to eq("TestApp")
      expect(described_class.configuration.hotwire_native.min_app_version).to eq("1.0")
      expect(described_class.configuration.short_code.default_length).to eq(10)
    end

    it "provides sensible defaults" do
      expect(described_class.configuration.hotwire_native.force_upgrade_path).to eq("/app/must-upgrade")
      expect(described_class.configuration.hotwire_native.header_prefix).to eq("X-App")
      expect(described_class.configuration.short_code.default_alphabet).to eq(:crockford)
      expect(described_class.configuration.short_code.default_length).to eq(8)
    end
  end
end

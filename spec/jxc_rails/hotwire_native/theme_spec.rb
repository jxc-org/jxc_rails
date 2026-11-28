# frozen_string_literal: true

require "spec_helper"
require "logger"
require "stringio"

RSpec.describe JxcRails::HotwireNative::Theme do
  let(:css) { File.expand_path("../../fixtures/theme/application.css", __dir__) }
  let(:light) { { background: "--bg", surface: "--surface", border: "--border", text: "--text", accent: "--coral-strong" } }
  let(:dark) { { background: "#111111", surface: "#1C1C1C", border: "#333333", text: "#F5F5F5", accent: "#FF8A6B" } }
  let(:log) { StringIO.new }
  let(:logger) { Logger.new(log) }

  before { JxcRails.reset_configuration! }
  after do
    JxcRails.reset_configuration!
    described_class.reset!
  end

  def configure(light: self.light, dark: nil)
    JxcRails.configure do |c|
      c.hotwire_native.theme.css_path = css
      c.hotwire_native.theme.light    = light
      c.hotwire_native.theme.dark     = dark
    end
  end

  def resolve(env: "production") = described_class.resolve!(env: env, logger: logger)

  # Records the calls a jbuilder template would make.
  let(:json) do
    Class.new do
      attr_reader :calls

      def initialize = @calls = {}
      def theme(value) = @calls[:theme] = value
      def background_color(value) = @calls[:background_color] = value
    end.new
  end
  let(:helper) { Class.new { include JxcRails::HotwireNative::Helper }.new }

  it "resolves a fixture CSS file into the exact schema, with background_color" do
    configure(dark: dark)
    resolve
    helper.hotwire_theme(json)

    expect(json.calls).to eq(
      theme: {
        version: 1,
        light: { background: "#FFFFFF", surface: "#F5F5F4", border: "#D6D3D1", text: "#1C1917", accent: "#B93A1C" },
        dark: { background: "#111111", surface: "#1C1C1C", border: "#333333", text: "#F5F5F5", accent: "#FF8A6B" }
      },
      background_color: "#FFFFFF"
    )
    expect(log.string).to be_empty
  end

  it "accepts literal #RRGGBB values and a null dark" do
    configure(light: dark)
    resolve
    expect(described_class.resolved).to eq(version: 1, light: dark, dark: nil)
  end

  it "emits nothing without config" do
    resolve(env: "test")
    helper.hotwire_theme(json)
    expect(described_class.resolved).to be_nil
    expect(json.calls).to be_empty
  end

  it "validates dark like light" do
    configure(dark: dark.merge(accent: "#333333"))
    expect { resolve(env: "test") }.to raise_error(JxcRails::ConfigurationError, /dark\.accent #333333 on dark\.surface/)
  end

  it "requires light when dark is given" do
    configure(light: nil, dark: dark)
    expect { resolve(env: "test") }.to raise_error(JxcRails::ConfigurationError, /light is required/)
  end

  it "computes WCAG ratios" do
    expect(described_class.contrast_ratio("#000000", "#FFFFFF")).to be_within(0.001).of(21)
    expect(described_class.contrast_ratio("#E05C3A", "#FFFFFF").round(2)).to eq(3.64)
  end

  {
    "a missing variable" => [{ accent: "--nope" }, /light\.accent: --nope not in :root/],
    "a 3.64:1 accent (#E05C3A on #FFFFFF)" => [{ accent: "--coral-light", surface: "#FFFFFF" },
                                               /light\.accent #E05C3A on light\.surface #FFFFFF is 3\.64:1/],
    "an rgb() value" => [{ background: "--rgb-bg" }, /not #RRGGBB/],
    "a literal rgb() value" => [{ background: "rgb(255, 255, 255)" }, /not #RRGGBB/],
    "a missing role" => [{ border: nil }, /light\.border is missing/]
  }.each do |name, (override, message)|
    context "with #{name}" do
      before { configure(light: light.merge(override).compact) }

      it "raises in the test environment" do
        expect { resolve(env: "test") }.to raise_error(JxcRails::ConfigurationError, message)
      end

      it "logs once and omits the theme in production" do
        resolve
        2.times { helper.hotwire_theme(json) }

        expect(json.calls).to be_empty
        expect(log.string.lines.size).to eq(1)
        expect(log.string).to match(message)
      end
    end
  end
end

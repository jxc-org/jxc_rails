# frozen_string_literal: true

require "spec_helper"

RSpec.describe JxcRails::ShortCode::Generator do
  it "generates a code of the requested length using the default alphabet" do
    code = described_class.new(length: 8).call
    expect(code.length).to eq(8)
    expect(code).to match(/\A[23456789abcdefghjkmnpqrstvwxyz]{8}\z/)
  end

  it "supports named alphabets" do
    code = described_class.new(alphabet: :uppercase_crockford, length: 5).call
    expect(code).to match(/\A[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{5}\z/)
  end

  it "supports custom string alphabets" do
    code = described_class.new(alphabet: "XY", length: 10).call
    expect(code).to match(/\A[XY]{10}\z/)
  end

  it "raises on unknown alphabet symbols" do
    expect { described_class.new(alphabet: :bogus) }.to raise_error(ArgumentError, /Unknown alphabet/)
  end
end

# frozen_string_literal: true

require "jxc_rails/variant_processor_check"

RSpec.describe JxcRails::VariantProcessorCheck do
  describe ".problem" do
    # Simulates a bundle: the listed gems are "present".
    def presence_of(*present)
      ->(name) { present.include?(name) }
    end

    it "flags :vips when ruby-vips is missing from the bundle (the incident)" do
      message = described_class.problem(
        processor: :vips,
        image_processing_present: true,
        gem_present: presence_of("image_processing", "mini_magick") # no ruby-vips
      )

      expect(message).to include("ruby-vips")
      expect(message).to include(":vips")
      expect(message).to include("not in the bundle")
    end

    it "passes :vips when ruby-vips is present (1.x bundled, or 2.x + explicit gem)" do
      message = described_class.problem(
        processor: :vips,
        image_processing_present: true,
        gem_present: presence_of("image_processing", "ruby-vips")
      )

      expect(message).to be_nil
    end

    it "flags :mini_magick when mini_magick is missing" do
      message = described_class.problem(
        processor: :mini_magick,
        image_processing_present: true,
        gem_present: presence_of("image_processing") # no mini_magick
      )

      expect(message).to include("mini_magick")
    end

    it "accepts a string processor (config may set either)" do
      message = described_class.problem(
        processor: "vips",
        image_processing_present: true,
        gem_present: presence_of("image_processing") # no ruby-vips
      )

      expect(message).to include("ruby-vips")
    end

    it "no-ops when image_processing is not in the bundle (app doesn't process images)" do
      message = described_class.problem(
        processor: :vips,
        image_processing_present: false,
        gem_present: presence_of # nothing present
      )

      expect(message).to be_nil
    end

    it "no-ops for an unknown / custom processor it can't reason about" do
      message = described_class.problem(
        processor: :something_custom,
        image_processing_present: true,
        gem_present: presence_of("image_processing")
      )

      expect(message).to be_nil
    end
  end

  describe ".gem_present?" do
    it "is true for a gem that is actually installed" do
      expect(described_class.gem_present?("rspec")).to be(true)
    end

    it "is false for a gem that is not installed" do
      expect(described_class.gem_present?("definitely-not-a-real-gem-xyz")).to be(false)
    end
  end

  describe ".smoke!" do
    it "processes the embedded sample image through the configured processor" do
      # Skip unless ruby-vips + libvips are actually available in this env.
      skip "ruby-vips not installed" unless described_class.gem_present?("ruby-vips")

      bytes = described_class.smoke!(env: "test", logger: nil)

      expect(bytes).to be > 0
    end
  end
end

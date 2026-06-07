# frozen_string_literal: true

module JxcRails
  # Boot-time guard against the "a dependency bump passes the test suite but
  # silently breaks a runtime code path" class of bug.
  #
  # The motivating incident: bumping +image_processing+ from 1.x to 2.x dropped
  # its auto-bundled +ruby-vips+ dependency. Apps configured with
  # +config.active_storage.variant_processor = :vips+ kept rendering
  # +photo.variant(...)+, but the backing gem was gone from the bundle, so
  # variant processing raised +LoadError+ in production while RSpec stayed green
  # (no test actually processed a variant).
  #
  # This check runs in +after_initialize+ in every host app (wired by the
  # Railtie) and asserts that the gem backing the configured variant processor
  # is present in the bundle. It is deliberately cheap and environment
  # independent: it inspects gem specs only and never loads the native libvips /
  # ImageMagick libraries, so it is safe to run during +assets:precompile+ (which
  # gates the Docker image for apps without a test job) and on every boot.
  #
  # The heavier *functional* proof — actually processing an image end to end —
  # lives in {.smoke!}, exposed as the +jxc_rails:variant_processor:smoke+ rake
  # task for CI, where libvips is guaranteed to be installed.
  module VariantProcessorCheck
    # Maps a configured ActiveStorage variant processor to the gem that backs it.
    BACKING_GEMS = { vips: "ruby-vips", mini_magick: "mini_magick" }.freeze

    # A 16x16 PNG, base64-encoded, used as the source image for {.smoke!} so the
    # check is self-contained and needs no per-app fixture.
    SAMPLE_PNG_BASE64 = <<~B64
      iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAtGVYSWZJSSoACAAAAAYAEgEDAAEA
      AAABAAAAGgEFAAEAAABWAAAAGwEFAAEAAABeAAAAKAEDAAEAAAACAAAAEwIDAAEAAAABAAAAaYcE
      AAEAAABmAAAAAAAAADhjAADoAwAAOGMAAOgDAAAGAACQBwAEAAAAMDIxMAGRBwAEAAAAAQIDAACg
      BwAEAAAAMDEwMAGgAwABAAAA//8AAAKgBAABAAAAEAAAAAOgBAABAAAAEAAAAAAAAAAc8ev6AAAA
      CXBIWXMAAAPoAAAD6AG1e1JrAAAAFklEQVQokWMIqFhAEmIY1TCqYfhqAAATWWgQ5omZdgAAAABJ
      RU5ErkJggg==
    B64

    class << self
      # Boot-time assertion. Returns nil. Raises JxcRails::ConfigurationError in
      # the configured fail-fast environments (production by default) when the
      # backing gem is missing; otherwise logs a warning. Safe to call when
      # ActiveStorage / image_processing are not in use — it no-ops.
      def run!(env: current_env, logger: default_logger, processor: configured_variant_processor)
        return unless defined?(ActiveStorage)

        message = problem(
          processor: processor,
          image_processing_present: gem_present?("image_processing"),
          gem_present: method(:gem_present?)
        )
        return if message.nil?

        return logger&.warn("[jxc_rails] #{message}") unless raise_in?(env)

        raise JxcRails::ConfigurationError, "[jxc_rails] #{message}"
      end

      # The variant processor ActiveStorage will actually use at runtime.
      #
      # Read from the app's *config* — NOT from +ActiveStorage.variant_processor+
      # — on purpose. That module attribute is assigned from config inside
      # ActiveStorage's own +config.after_initialize+ hook (see
      # activestorage/lib/active_storage/engine.rb), which is a *peer* of the
      # +after_initialize+ this check runs in (wired by the Railtie). Their
      # relative order is not guaranteed; in practice this check often wins the
      # race and reads the bare mattr default (+:mini_magick+) before the app's
      # +config.active_storage.variant_processor = :vips+ has been applied —
      # producing a false "mini_magick is not in the bundle" failure that breaks
      # +assets:precompile+ / boot for apps that are correctly configured for
      # +:vips+. +app.config+ is fully settled before any +after_initialize+
      # runs, so reading it here is order-independent. The +|| :mini_magick+
      # fallback mirrors ActiveStorage's own resolution for an unconfigured app.
      def configured_variant_processor(app: rails_application)
        return activestorage_default_processor unless app

        app.config.active_storage.variant_processor || activestorage_default_processor
      end

      # Pure decision logic, dependency-injected so it is unit-testable without a
      # Rails app, ActiveStorage, or a real bundle. Returns an error message
      # String when the configured processor's backing gem is missing, else nil.
      #
      # +gem_present+ is a callable taking a gem name and returning a boolean.
      def problem(processor:, image_processing_present:, gem_present:)
        # If the app doesn't pull in image_processing at all, it isn't doing
        # ActiveStorage variant processing — nothing to assert.
        return nil unless image_processing_present

        backing_gem = BACKING_GEMS[processor&.to_sym]
        # Unknown / custom processor: we can't know its backing gem, so stay out
        # of the way rather than guess.
        return nil if backing_gem.nil?
        return nil if gem_present.call(backing_gem)

        "ActiveStorage.variant_processor is #{processor.inspect} but its backing " \
          "gem #{backing_gem.inspect} is not in the bundle — image variants will " \
          "raise at runtime. Add `gem #{backing_gem.inspect}` to your Gemfile " \
          "(image_processing 2.x no longer bundles it)."
      end

      # Functional proof: process a real image through the configured processor,
      # exercising gem + native library + image_processing API together. Raises
      # on any failure. Returns the byte size of the produced image. Used by the
      # +jxc_rails:variant_processor:smoke+ rake task in CI.
      def smoke!(env: current_env, logger: default_logger, size: 16)
        require "image_processing"
        require "tempfile"

        processor = (defined?(ActiveStorage) && ActiveStorage.variant_processor) || :vips
        source = write_sample_image
        result = processor_module(processor).source(source.path).resize_to_limit!(size, size)
        bytes = File.size(result.path)
        raise "variant processing produced empty output" if bytes.to_i.zero?

        logger&.info("[jxc_rails] variant_processor smoke OK processor=#{processor} bytes=#{bytes} env=#{env}")
        bytes
      ensure
        result&.close!
        source&.close!
      end

      # True when +name+ resolves to a gem spec. Under Bundler (how a deployed
      # Rails app boots) this reflects the bundle / lockfile, which is exactly
      # the signal we want: a dependency bump that drops a gem makes this false.
      # Does not load the gem, so no native library is touched.
      def gem_present?(name)
        Gem::Specification.find_by_name(name)
        true
      rescue Gem::MissingSpecError
        false
      end

      private

      def rails_application
        Rails.application if defined?(Rails) && Rails.respond_to?(:application)
      end

      # ActiveStorage's fallback when the app sets no processor (engine.rb:
      # +app.config.active_storage.variant_processor || :mini_magick+). The
      # mattr default is also :mini_magick, so reading it here stays correct
      # whether or not ActiveStorage's own after_initialize has run yet.
      def activestorage_default_processor
        (ActiveStorage.variant_processor if defined?(ActiveStorage)) || :mini_magick
      end

      def raise_in?(env)
        Array(JxcRails.config.variant_processor_check.raise_environments)
          .map(&:to_s).include?(env.to_s)
      end

      # Resolves the ImageProcessing module the same way ActiveStorage does:
      # :vips => ImageProcessing::Vips, :mini_magick => ImageProcessing::MiniMagick.
      def processor_module(processor)
        require "image_processing/#{processor}"
        ImageProcessing.const_get(processor.to_s.split("_").map(&:capitalize).join)
      end

      def write_sample_image
        Tempfile.new(["jxc_rails_variant_smoke", ".png"], binmode: true).tap do |file|
          file.write(SAMPLE_PNG_BASE64.unpack1("m"))
          file.flush
        end
      end

      def current_env
        if defined?(Rails) && Rails.respond_to?(:env)
          Rails.env
        else
          ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"
        end
      end

      def default_logger
        return Rails.logger if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger

        nil
      end
    end
  end
end

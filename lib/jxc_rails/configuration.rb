# frozen_string_literal: true

module JxcRails
  class Configuration
    attr_reader :hotwire_native, :persistent_login, :short_code, :variant_processor_check

    def initialize
      @hotwire_native          = HotwireNativeConfig.new
      @persistent_login        = PersistentLoginConfig.new
      @short_code              = ShortCodeConfig.new
      @variant_processor_check = VariantProcessorCheckConfig.new
    end

    class HotwireNativeConfig
      attr_accessor :app_name, :min_app_version, :force_upgrade_path, :header_prefix

      def initialize
        @app_name           = nil
        @min_app_version    = nil
        @force_upgrade_path = "/app/must-upgrade"
        @header_prefix      = "X-App"
      end
    end

    class PersistentLoginConfig
      attr_accessor :remember_for, :extend_remember_period

      def initialize
        @remember_for           = 1.year
        @extend_remember_period = true
      end
    end

    class ShortCodeConfig
      attr_accessor :default_alphabet, :default_length

      def initialize
        @default_alphabet = :crockford
        @default_length   = 8
      end
    end

    class VariantProcessorCheckConfig
      # Whether the boot-time variant-processor assertion runs at all.
      attr_accessor :enabled
      # Rails environments in which a missing backing gem raises (and so fails
      # boot / assets:precompile / the deploy). Other environments warn only.
      attr_accessor :raise_environments

      def initialize
        @enabled            = true
        @raise_environments = %w[production]
      end
    end
  end
end

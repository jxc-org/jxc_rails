# frozen_string_literal: true

module JxcRails
  module Posthog
    module Config
      def self.build_client(api_key: ENV["POSTHOG_API_KEY"],
                            host: JxcRails::Posthog.api_host,
                            personal_api_key: ENV["POSTHOG_FEATURE_FLAGS_KEY"],
                            feature_flags_polling_interval: 600,
                            on_error: nil)
        return nil if api_key.nil? || api_key.empty?

        require "posthog" unless defined?(::PostHog::Client)
        ::PostHog::Client.new(
          api_key: api_key,
          host: host,
          personal_api_key: personal_api_key,
          feature_flags_polling_interval: feature_flags_polling_interval,
          on_error: on_error || default_on_error
        )
      end

      def self.default_on_error
        lambda do |status, msg|
          if defined?(::Rails) && ::Rails.respond_to?(:logger) && ::Rails.logger
            ::Rails.logger.warn("[posthog] #{status}: #{msg}")
          else
            warn("[posthog] #{status}: #{msg}")
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module JxcRails
  module FeatureFlags
    class << self
      attr_accessor :client, :distinct_id_resolver

      def enabled?(flag, actor = nil, person_properties: {})
        return overrides[flag] if overrides.key?(flag)
        return false unless client

        distinct_id = resolve_distinct_id(actor)
        return false unless distinct_id

        client.is_feature_enabled(flag, distinct_id, person_properties: person_properties)
      end

      def track(event, actor, **properties)
        return unless client

        distinct_id = resolve_distinct_id(actor)
        return unless distinct_id

        client.capture(distinct_id: distinct_id, event: event, properties: properties)
      end

      def override(flag, value)
        overrides[flag] = value
      end

      def reload!
        client&.reload_feature_flags
      end

      def clear_overrides!
        @overrides = {}
      end

      private

      def overrides
        @overrides ||= {}
      end

      def resolve_distinct_id(actor)
        return nil if actor.nil?

        if distinct_id_resolver
          distinct_id_resolver.call(actor)
        elsif actor.respond_to?(:short_code)
          actor.short_code
        elsif actor.respond_to?(:id)
          actor.id.to_s
        end
      end
    end

    module ControllerConcern
      extend ActiveSupport::Concern

      included do
        helper_method :feature_enabled? if respond_to?(:helper_method)
      end

      private

      def feature_enabled?(flag, actor = current_user, **opts)
        JxcRails::FeatureFlags.enabled?(flag, actor, **opts)
      end
    end
  end
end

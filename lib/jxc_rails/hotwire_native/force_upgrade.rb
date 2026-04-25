# frozen_string_literal: true

require "active_support/concern"

module JxcRails
  module HotwireNative
    # Mix into ApplicationController to redirect below-minimum Hotwire Native
    # clients to a "must upgrade" page served from the same web origin.
    #
    #   class ApplicationController < ActionController::Base
    #     include JxcRails::HotwireNative::ForceUpgrade
    #   end
    #
    # No-op when:
    # - no `min_app_version` configured
    # - request is not from a Hotwire Native client (ClientVersion.from_request returns nil)
    # - request is already for the force-upgrade path (avoid redirect loop)
    # - request format is JSON (path_configuration endpoint handles itself)
    module ForceUpgrade
      extend ActiveSupport::Concern

      included do
        before_action :redirect_if_app_version_below_minimum
      end

      private

      def redirect_if_app_version_below_minimum
        upgrade_path = JxcRails.configuration.hotwire_native.force_upgrade_path
        return if request.path == upgrade_path
        return if request.format.json?

        reason = if force_upgrade_via_feature_flag?
                   "feature_flag"
                 elsif force_upgrade_via_min_version?
                   "min_version"
                 end
        return unless reason

        client = ClientVersion.from_request(request)
        JxcRails::FeatureFlags.track("force_upgrade_shown",
          current_user,
          reason: reason,
          app_version: client&.version
        )
        redirect_to upgrade_path, allow_other_host: false
      end

      def force_upgrade_via_min_version?
        min = JxcRails.configuration.hotwire_native.min_app_version
        return false if min.blank?

        client = ClientVersion.from_request(request)
        client&.below?(min)
      end

      def force_upgrade_via_feature_flag?
        return false unless turbo_native_app?
        return false unless respond_to?(:current_user, true) && current_user

        JxcRails::FeatureFlags.enabled?("force-upgrade-test", current_user)
      end
    end
  end
end

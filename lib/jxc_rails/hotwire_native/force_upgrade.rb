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
        min = JxcRails.configuration.hotwire_native.min_app_version
        return if min.blank?

        upgrade_path = JxcRails.configuration.hotwire_native.force_upgrade_path
        return if request.path == upgrade_path
        return if request.format.json?

        client = ClientVersion.from_request(request)
        return unless client&.below?(min)

        redirect_to upgrade_path, allow_other_host: false
      end
    end
  end
end

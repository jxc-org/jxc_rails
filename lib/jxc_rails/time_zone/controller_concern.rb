# frozen_string_literal: true

require "active_support/concern"

module JxcRails
  module TimeZone
    # Include in ApplicationController (needs `current_user`).
    module ControllerConcern
      extend ActiveSupport::Concern

      included do
        before_action :jxc_capture_time_zone
        around_action :jxc_use_time_zone
      end

      private

      # Fills a blank zone from the jxc_tz cookie, once. A stored zone is never
      # overwritten, so travelling with the device doesn't move the user's zone.
      def jxc_capture_time_zone
        user = current_user
        return unless user && user.time_zone.blank?

        zone = cookies[JxcRails::TimeZone::COOKIE]
        user.update_column(:time_zone, zone) if JxcRails::TimeZone.valid?(zone)
      end

      def jxc_use_time_zone(&)
        JxcRails::TimeZone.use_for(current_user, &)
      end
    end
  end
end

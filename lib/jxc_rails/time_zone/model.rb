# frozen_string_literal: true

require "active_support/concern"

module JxcRails
  module TimeZone
    # Include in the app's User (needs a string `time_zone` column).
    module Model
      extend ActiveSupport::Concern

      included do
        validate do
          errors.add(:time_zone, :inclusion) if time_zone.present? && !JxcRails::TimeZone.valid?(time_zone)
        end
      end

      def effective_time_zone
        time_zone.presence || JxcRails.config.time_zone.default
      end
    end
  end
end

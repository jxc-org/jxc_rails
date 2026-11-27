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

      # An invalid stored id (bad data from before validation, a tzdata change) falls back too.
      def effective_time_zone
        JxcRails::TimeZone.valid?(time_zone) ? time_zone : JxcRails.config.time_zone.default
      end
    end
  end
end

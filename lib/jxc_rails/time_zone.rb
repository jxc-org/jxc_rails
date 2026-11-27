# frozen_string_literal: true

require "tzinfo"

module JxcRails
  # Per-user time zones. Include `Model` in the User, `ControllerConcern` in
  # ApplicationController, and render `jxc_time_zone_capture_tag` in the layout
  # <head>. Use `use_for(user) { ... }` in jobs and mailers.
  module TimeZone
    COOKIE = "jxc_tz"

    autoload :ControllerConcern, "jxc_rails/time_zone/controller_concern"
    autoload :Model,             "jxc_rails/time_zone/model"
    autoload :ViewHelper,        "jxc_rails/time_zone/view_helper"

    class << self
      # Strict IANA identifier check (no Rails friendly names like "Eastern Time (US & Canada)").
      def valid?(id)
        id.is_a?(String) && identifiers.include?(id)
      end

      def use_for(user, &)
        Time.use_zone(user&.effective_time_zone || JxcRails.config.time_zone.default, &)
      end

      private

      def identifiers
        @identifiers ||= TZInfo::Timezone.all_identifiers.to_set
      end
    end
  end
end

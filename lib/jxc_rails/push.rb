# frozen_string_literal: true

module JxcRails
  # Push notifications over Rails' action_push_native (direct APNs, no third-party
  # service). Include `Model` in the app's ApplicationPushDevice, `ControllerConcern`
  # in its DevicesController, and call `ApplicationPushDevice.unregister` on sign-out.
  #
  # An APNs 410 or BadDeviceToken needs no code here: action_push_native raises
  # TokenError and its Device already `destroy!`s on it.
  module Push
    autoload :ControllerConcern, "jxc_rails/push/controller_concern"
    autoload :Model,             "jxc_rails/push/model"

    # config/push.yml keys that must be present for a platform to send.
    REQUIRED_CONFIG = {
      "apple" => %i[key_id team_id encryption_key topic],
      "google" => %i[encryption_key project_id]
    }.freeze

    class << self
      def configured?(platform, notification)
        config = ActionPushNative.config_for(platform, notification)
        REQUIRED_CONFIG.fetch(platform.to_s, []).all? { |key| config[key].present? }
      rescue StandardError # no config/push.yml, or the platform has no block
        false
      end

      # Never pass the token or the notification here: this line is all that is logged.
      def log_skipped(platform)
        Rails.logger&.info("JxcRails::Push: #{platform} push credentials not configured; skipping send")
        nil
      end
    end
  end
end

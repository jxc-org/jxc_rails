# frozen_string_literal: true

require "active_support/concern"

module JxcRails
  module Push
    # Include in the app's ApplicationPushDevice (an ActionPushNative::Device whose
    # `owner` is the user).
    module Model
      extend ActiveSupport::Concern

      class_methods do
        # Upsert by token: a token already owned by someone else moves to `owner`,
        # dropping the previous owner's device name unless a new one is passed.
        # ponytail: find-then-save, so two simultaneous first registrations of one
        # token can make two rows; add a unique index on token + rescue RecordNotUnique to close it.
        def register(owner:, token:, platform: "apple", name: nil)
          device = find_or_initialize_by(token: token, platform: platform)
          device.name = name if name || device.owner != owner
          device.owner = owner
          device.save!
          device
        end

        # Sign-out hook: destroys the owner's device for this session, by token or id.
        # Another user's device (or no match) is left alone.
        def unregister(owner:, token: nil, id: nil)
          return if token.blank? && id.blank?

          where(owner: owner).where({ token: token, id: id }.compact).destroy_all
        end
      end

      # Skip, with one log line, instead of raising while APNs credentials are not set up.
      def push(notification)
        return JxcRails::Push.log_skipped(platform) unless JxcRails::Push.configured?(platform, notification)

        super
      end
    end
  end
end

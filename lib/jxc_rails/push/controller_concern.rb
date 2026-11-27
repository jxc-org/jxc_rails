# frozen_string_literal: true

require "active_support/concern"

module JxcRails
  module Push
    # Include in the app's DevicesController (needs `current_user`) and route
    # `resources :devices, only: %i[create destroy]`. POST takes token (required),
    # platform (default "apple") and name.
    module ControllerConcern
      extend ActiveSupport::Concern

      included do
        before_action { head :unauthorized unless current_user }
        rescue_from(ActiveRecord::RecordNotFound) { head :not_found }
        rescue_from(ActiveRecord::RecordInvalid) { head :unprocessable_content }
      end

      def create
        device = ApplicationPushDevice.register(
          owner: current_user, token: params.require(:token),
          platform: params.fetch(:platform, "apple"), name: params[:name]
        )
        render json: { id: device.id }, status: :created
      end

      # Only the caller's own device; another user's id is a 404 and the device survives.
      def destroy
        ApplicationPushDevice.where(owner: current_user).find(params[:id]).destroy!
        head :no_content
      end
    end
  end
end

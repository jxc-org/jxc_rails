# frozen_string_literal: true

require "active_support/concern"

module JxcRails
  module PersistentLogin
    # Include in a Devise registrations controller so new Hotwire Native
    # sign-ups are remembered by default.
    #
    #   class Users::RegistrationsController < Devise::RegistrationsController
    #     include JxcRails::PersistentLogin::Registrations
    #   end
    module Registrations
      extend ActiveSupport::Concern

      included do
        include Devise::Controllers::Rememberable
      end

      def create
        super do |resource|
          remember_me(resource) if resource.persisted? && turbo_native_app?
          yield resource if block_given?
        end
      end
    end
  end
end

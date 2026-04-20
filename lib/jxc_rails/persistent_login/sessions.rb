# frozen_string_literal: true

require "active_support/concern"

module JxcRails
  module PersistentLogin
    # Include in a Devise sessions controller to automatically call
    # `remember_me(resource)` when a Hotwire Native client signs in.
    #
    #   class Users::SessionsController < Devise::SessionsController
    #     include JxcRails::PersistentLogin::Sessions
    #   end
    #
    # Subclasses can still pass their own block to `super` for additional
    # work on sign-in; this concern only handles the remember_me flip.
    module Sessions
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

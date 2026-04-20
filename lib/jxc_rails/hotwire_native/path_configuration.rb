# frozen_string_literal: true

require "active_support/concern"

module JxcRails
  module HotwireNative
    # Mix into a controller to serve a version-aware path configuration JSON.
    #
    #   class HotwireNativeController < ApplicationController
    #     include JxcRails::HotwireNative::PathConfiguration
    #   end
    #
    # The accompanying jbuilder template (app/views/hotwire_native/path_configuration.json.jbuilder)
    # has access to `@hotwire_client` (ClientVersion or nil) and
    # `@hotwire_force_upgrade` (boolean), plus the Helper DSL (`rule`, `for_version`).
    module PathConfiguration
      extend ActiveSupport::Concern

      included do
        skip_before_action :verify_authenticity_token, raise: false
      end

      def path_configuration
        @hotwire_client = ClientVersion.from_request(request)
        min = JxcRails.configuration.hotwire_native.min_app_version
        @hotwire_force_upgrade = min.present? && @hotwire_client&.below?(min) || false

        response.set_header("Vary", "User-Agent, X-App-Version, X-App-Name, X-App-Build")
        response.set_header("Cache-Control", "private, no-store")

        respond_to do |format|
          format.json { render :path_configuration }
          format.any  { render :path_configuration, formats: [:json], content_type: "application/json" }
        end
      end
    end
  end
end

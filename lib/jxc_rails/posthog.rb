# frozen_string_literal: true

module JxcRails
  module Posthog
    DEFAULT_API_HOST = "https://abc.johnxcoulter.com"
    DEFAULT_UI_HOST = "https://us.posthog.com"

    def self.api_host
      ENV.fetch("POSTHOG_API_HOST", DEFAULT_API_HOST)
    end

    def self.ui_host
      ENV.fetch("POSTHOG_UI_HOST", DEFAULT_UI_HOST)
    end

    autoload :Helper, "jxc_rails/posthog/helper"
    autoload :Config, "jxc_rails/posthog/config"
  end
end

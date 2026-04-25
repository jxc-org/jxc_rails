# frozen_string_literal: true

module JxcRails
  module Posthog
    module Helper
      def posthog_native_register_tags
        source = turbo_native_app? ? "ios_webview" : "web"
        content_tag(:script, "if (window.posthog) posthog.register({app_source: '#{source}'});".html_safe)
      end
    end
  end
end

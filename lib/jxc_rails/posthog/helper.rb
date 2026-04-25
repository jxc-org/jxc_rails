# frozen_string_literal: true

module JxcRails
  module Posthog
    module Helper
      def posthog_native_register_tags
        return "".html_safe unless turbo_native_app?

        content_tag(:script, "if (window.posthog) posthog.register({app_source: 'ios_webview'});".html_safe)
      end
    end
  end
end

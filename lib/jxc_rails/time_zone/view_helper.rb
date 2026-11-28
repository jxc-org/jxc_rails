# frozen_string_literal: true

module JxcRails
  module TimeZone
    module ViewHelper
      # Inline script (no bundle, no route; fine in a WKWebView) that sets the
      # jxc_tz cookie while the signed-in user has no stored zone. Carries the CSP
      # nonce so a strict policy does not block it. Empty otherwise.
      def jxc_time_zone_capture_tag
        user = current_user
        return "" unless user && user.time_zone.blank?

        script = "try{document.cookie=#{JxcRails::TimeZone::COOKIE.to_json}+'='+" \
                 "encodeURIComponent(Intl.DateTimeFormat().resolvedOptions().timeZone)+" \
                 "'; path=/; max-age=31536000; SameSite=Lax'}catch(e){}"
        javascript_tag(script, nonce: true)
      end
    end
  end
end

# frozen_string_literal: true

require "json"

module JxcRails
  module Posthog
    module Helper
      LOADER_JS = <<~JS
        !function(t,e){var o,n,p,r;e.__SV||(window.posthog && window.posthog.__loaded)||(window.posthog=e,e._i=[],e.init=function(i,s,a){function g(t,e){var o=e.split(".");2==o.length&&(t=t[o[0]],e=o[1]),t[e]=function(){t.push([e].concat(Array.prototype.slice.call(arguments,0)))}}(p=t.createElement("script")).type="text/javascript",p.crossOrigin="anonymous",p.async=!0,p.src=s.api_host.replace(".i.posthog.com","-assets.i.posthog.com")+"/static/array.js",(r=t.getElementsByTagName("script")[0]).parentNode.insertBefore(p,r);var u=e;for(void 0!==a?u=e[a]=[]:a="posthog",u.people=u.people||[],u.toString=function(t){var e="posthog";return"posthog"!==a&&(e+="."+a),t||(e+=" (stub)"),e},u.people.toString=function(){return u.toString(1)+".people (stub)"},o="Ei Ni init zi Gi Nr Ui Xi Hi capture calculateEventProperties tn register register_once register_for_session unregister unregister_for_session an getFeatureFlag getFeatureFlagPayload getFeatureFlagResult isFeatureEnabled reloadFeatureFlags updateFlags updateEarlyAccessFeatureEnrollment getEarlyAccessFeatures on onFeatureFlags onSurveysLoaded onSessionId getSurveys getActiveMatchingSurveys renderSurvey displaySurvey cancelPendingSurvey canRenderSurvey canRenderSurveyAsync ln identify setPersonProperties group resetGroups setPersonPropertiesForFlags resetPersonPropertiesForFlags setGroupPropertiesForFlags resetGroupPropertiesForFlags reset setIdentity clearIdentity get_distinct_id getGroups get_session_id get_session_replay_url alias set_config startSessionRecording stopSessionRecording sessionRecordingStarted captureException addExceptionStep captureLog startExceptionAutocapture stopExceptionAutocapture loadToolbar get_property getSessionProperty nn Qi createPersonProfile setInternalOrTestUser sn qi cn opt_in_capturing opt_out_capturing has_opted_in_capturing has_opted_out_capturing get_explicit_consent_status is_capturing clear_opt_in_out_capturing Ji debug Fr rn getPageViewId captureTraceFeedback captureTraceMetric Bi".split(" "),n=0;n<o.length;n++)g(u,o[n]);e._i.push([i,s,a])},e.__SV=1)}(document,window.posthog||[]);
      JS

      def posthog_native_register_tags
        source = turbo_native_app? ? "ios_webview" : "web"
        content_tag(:script, "if (window.posthog) posthog.register({app_source: '#{source}'});".html_safe)
      end

      def posthog_snippet(api_key:, **options)
        return if api_key.nil? || api_key.empty?

        init_options = {
          api_host: JxcRails::Posthog.api_host,
          ui_host: JxcRails::Posthog.ui_host
        }.merge(options)

        key_json = JxcRails::Posthog::Helper.script_safe_json(api_key)
        opts_json = JxcRails::Posthog::Helper.script_safe_json(init_options)
        script = "#{LOADER_JS}posthog.init(#{key_json}, #{opts_json});"
        content_tag(:script, script.html_safe)
      end

      def self.script_safe_json(value)
        value.to_json
             .gsub("</", "<\\/")
             .gsub(" ", "\\u2028")
             .gsub(" ", "\\u2029")
      end
    end
  end
end

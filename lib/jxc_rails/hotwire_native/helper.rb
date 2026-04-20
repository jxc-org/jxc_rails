# frozen_string_literal: true

module JxcRails
  module HotwireNative
    # View helpers for authoring a `path_configuration.json.jbuilder`
    # template with version-gated rules.
    #
    #   json.settings do
    #     json.screenshots_enabled true
    #   end
    #
    #   json.rules do
    #     rule(json, patterns: ["^/$"], presentation: "replace_root")
    #
    #     for_version(min: "2.0") do
    #       rule(json, patterns: ["^/settings$"], presentation: "replace_root")
    #     end
    #
    #     if @hotwire_force_upgrade
    #       rule(json, patterns: [".*"], presentation: "replace_root", redirect_url: "/app/must-upgrade")
    #     end
    #
    #     rule(json, patterns: [".*"], presentation: "push")
    #   end
    module Helper
      # Emit a single Hotwire Native rule — a `{ patterns: [], properties: {} }` entry.
      def rule(json, patterns:, **properties)
        json.child! do
          json.patterns Array(patterns)
          json.properties do
            properties.each { |k, v| json.set!(k, v) }
          end
        end
      end

      # Yield when the current client is nil (browser) or falls within the version range.
      # Without `min`/`max`, always yields.
      def for_version(min: nil, max: nil)
        return yield if @hotwire_client.nil?
        yield if @hotwire_client.in_range?(min: min, max: max)
      end

      # Yield only when the current client is a Hotwire Native client at or above `min`.
      def only_native_at_least(min)
        return if @hotwire_client.nil?
        yield if @hotwire_client.at_least?(min)
      end
    end
  end
end

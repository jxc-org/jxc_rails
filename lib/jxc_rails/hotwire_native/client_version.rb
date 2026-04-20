# frozen_string_literal: true

module JxcRails
  module HotwireNative
    # Parses app-identifying headers or the User-Agent string from a Rails
    # request into a comparable ClientVersion. Returns nil when no identifying
    # information is present (e.g. a plain browser request).
    #
    #   client = JxcRails::HotwireNative::ClientVersion.from_request(request)
    #   client&.below?("2.0") # => true/false
    class ClientVersion
      attr_reader :app_name, :version, :build

      def initialize(app_name:, version:, build: nil)
        @app_name = app_name
        @version  = ::Gem::Version.new(version.to_s)
        @build    = build&.to_i
      end

      def self.from_request(request)
        prefix = JxcRails.configuration.hotwire_native.header_prefix

        header_name    = request.headers["#{prefix}-Name"]
        header_version = request.headers["#{prefix}-Version"]
        header_build   = request.headers["#{prefix}-Build"]

        return new(app_name: header_name, version: header_version, build: header_build) if header_version.present?

        parse_user_agent(request.user_agent.to_s)
      end

      def self.parse_user_agent(ua)
        return nil if ua.blank?

        # Matches e.g. "Birthdaze/2.1.0 (build 42)" or "Birthdaze/2.1.0" anywhere in the UA
        match = ua.match(%r{(?<name>[A-Za-z][\w.\-]*)/(?<version>\d+(?:\.\d+){0,3})(?:\s*\(build\s+(?<build>\d+)\))?})
        return nil unless match

        new(app_name: match[:name], version: match[:version], build: match[:build])
      rescue ArgumentError
        nil
      end

      def at_least?(min)
        version >= ::Gem::Version.new(min.to_s)
      end

      def below?(min)
        version < ::Gem::Version.new(min.to_s)
      end

      def in_range?(min: nil, max: nil)
        (min.nil? || at_least?(min)) && (max.nil? || version < ::Gem::Version.new(max.to_s))
      end

      def to_s
        "#{app_name}/#{version}#{" (build #{build})" if build}"
      end
    end
  end
end

# frozen_string_literal: true

module JxcRails
  module HotwireNative
    # Native colors served inside the path-configuration `settings` block, so iOS
    # follows the web without an App Store build.
    #
    #   JxcRails.configure do |c|
    #     c.hotwire_native.theme.light = { background: "--bg", surface: "--surface", border: "--border",
    #                                      text: "--text", accent: "#C2410C" }
    #     c.hotwire_native.theme.dark  = { ... } # optional, same five roles
    #   end
    #
    # Resolved once at boot (see the Railtie) and emitted by Helper#hotwire_theme.
    # A bad theme raises JxcRails::ConfigurationError in the test environment (so
    # the app's CI fails) and is logged once and omitted everywhere else.
    module Theme
      ROLES = %i[background surface border text accent].freeze
      HEX = /\A#\h{6}\z/
      MIN_CONTRAST = 4.5
      # [foreground, background] pairs that must reach MIN_CONTRAST.
      CONTRAST_PAIRS = [%i[text background], %i[text surface], %i[accent surface], %i[accent background]].freeze

      class << self
        # The theme Hash (symbol keys) or nil when unconfigured or invalid.
        def resolved
          resolve! unless defined?(@resolved)
          @resolved
        end

        def resolve!(config: JxcRails.config.hotwire_native.theme, env: current_env, logger: default_logger)
          @resolved = build(config)
        rescue JxcRails::ConfigurationError => e
          raise if env.to_s == "test"

          logger&.warn("#{e.message} — native theme omitted")
          @resolved = nil
        end

        def reset!
          remove_instance_variable(:@resolved) if defined?(@resolved)
        end

        # WCAG 2.x contrast ratio between two #RRGGBB colors.
        def contrast_ratio(one, other)
          hi, lo = [luminance(one), luminance(other)].sort.reverse
          (hi + 0.05) / (lo + 0.05)
        end

        private

        def build(config)
          return nil if config.light.nil? && config.dark.nil?

          css = nil
          vars = -> { css ||= root_variables(config.css_path) } # only read when a role names a --variable
          light = palette(:light, config.light, vars)
          dark = config.dark && palette(:dark, config.dark, vars)
          { version: 1, light: light, dark: dark }.freeze
        end

        def palette(name, map, vars)
          raise ConfigurationError, "[jxc_rails] hotwire_native.theme.light is required" if map.nil?

          map = map.to_h.transform_keys(&:to_sym)
          problems = (ROLES - map.keys).map { |r| "#{name}.#{r} is missing" } +
                     (map.keys - ROLES).map { |r| "#{name}.#{r} is not a theme role" }
          raise ConfigurationError, "[jxc_rails] #{problems.join("; ")}" if problems.any?

          colors = ROLES.to_h { |role| [role, color(name, role, map[role], vars)] }
          check_contrast(name, colors)
          colors.freeze
        end

        def check_contrast(name, colors)
          CONTRAST_PAIRS.each do |fg, bg|
            ratio = contrast_ratio(colors[fg], colors[bg])
            next if ratio >= MIN_CONTRAST

            raise ConfigurationError, "[jxc_rails] #{name}.#{fg} #{colors[fg]} on #{name}.#{bg} #{colors[bg]} is " \
                                      "#{ratio.round(2)}:1, needs #{MIN_CONTRAST}:1"
          end
        end

        def color(name, role, value, vars)
          value = value.to_s.strip
          raw = if value.start_with?("--")
                  vars.call.fetch(value) { raise ConfigurationError, "[jxc_rails] #{name}.#{role}: #{value} not in :root" }
                else
                  value
                end
          raise ConfigurationError, "[jxc_rails] #{name}.#{role}: #{raw.inspect} is not #RRGGBB" unless HEX.match?(raw)

          raw.upcase
        end

        # { "--name" => "value" } from every :root block of the stylesheet.
        def root_variables(path)
          file = File.expand_path(path, root)
          raise ConfigurationError, "[jxc_rails] theme css_path #{file} not found" unless File.file?(file)

          css = File.read(file).gsub(%r{/\*.*?\*/}m, "")
          css.scan(/:root\s*\{([^}]*)\}/m).flatten.flat_map { |body| body.scan(/(--[\w-]+)\s*:\s*([^;]+?)\s*(?:;|\z)/) }.to_h
        end

        def luminance(hex)
          r, g, b = hex.delete("#").scan(/../).map { |c| c.hex / 255.0 }.map do |c|
            c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055)**2.4
          end
          (0.2126 * r) + (0.7152 * g) + (0.0722 * b)
        end

        def root
          defined?(Rails) && Rails.respond_to?(:root) && Rails.root ? Rails.root.to_s : Dir.pwd
        end

        def current_env
          defined?(Rails) && Rails.respond_to?(:env) ? Rails.env : ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"
        end

        def default_logger
          Rails.logger if defined?(Rails) && Rails.respond_to?(:logger)
        end
      end
    end
  end
end

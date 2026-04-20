# frozen_string_literal: true

require "active_support"
require "active_support/core_ext/integer/time"
require "active_support/core_ext/numeric/time"
require "active_support/core_ext/object/blank"

require_relative "jxc_rails/version"
require_relative "jxc_rails/configuration"

module JxcRails
  class Error < StandardError; end
  class ConfigurationError < Error; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end

  autoload :HotwireNative,   "jxc_rails/hotwire_native"
  autoload :PersistentLogin, "jxc_rails/persistent_login"
  autoload :ShortCode,       "jxc_rails/short_code"
end

require_relative "jxc_rails/railtie" if defined?(Rails::Railtie)

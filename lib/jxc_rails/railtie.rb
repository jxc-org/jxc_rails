# frozen_string_literal: true

require "rails/railtie"

module JxcRails
  class Railtie < ::Rails::Railtie
    initializer "jxc_rails.short_code" do
      ActiveSupport.on_load(:active_record) do
        require "jxc_rails/short_code/concern"
        extend JxcRails::ShortCode::Concern
      end
    end

    initializer "jxc_rails.hotwire_native.view_helper" do
      ActiveSupport.on_load(:action_view) do
        require "jxc_rails/hotwire_native/helper"
        include JxcRails::HotwireNative::Helper
      end
    end

    initializer "jxc_rails.posthog.view_helper" do
      ActiveSupport.on_load(:action_view) do
        require "jxc_rails/posthog/helper"
        include JxcRails::Posthog::Helper
      end
    end

    initializer "jxc_rails.persistent_login.view_helper" do
      ActiveSupport.on_load(:action_view) do
        require "jxc_rails/persistent_login/view_helper"
        include JxcRails::PersistentLogin::ViewHelper
      end
    end
  end
end

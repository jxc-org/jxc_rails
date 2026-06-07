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

    initializer "jxc_rails.feature_flags" do
      ActiveSupport.on_load(:action_controller_base) do
        include JxcRails::FeatureFlags::ControllerConcern
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

    # Guard against a dependency bump that drops the gem backing the configured
    # ActiveStorage variant processor (e.g. image_processing 2.x dropping
    # ruby-vips). Runs in after_initialize, but reads the processor from
    # app.config rather than ActiveStorage.variant_processor — the latter is
    # itself assigned in a *peer* after_initialize hook whose ordering relative
    # to this one is not guaranteed. See JxcRails::VariantProcessorCheck.
    initializer "jxc_rails.variant_processor_check" do |app|
      app.config.after_initialize do
        next unless JxcRails.config.variant_processor_check.enabled

        require "jxc_rails/variant_processor_check"
        JxcRails::VariantProcessorCheck.run!
      end
    end

    rake_tasks do
      load File.expand_path("tasks/variant_processor.rake", __dir__)
    end
  end
end

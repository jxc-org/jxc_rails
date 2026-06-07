# frozen_string_literal: true

namespace :jxc_rails do
  namespace :variant_processor do
    desc "Process a real image through the configured ActiveStorage variant " \
         "processor (proves the gem + native library + image_processing API all work)"
    task smoke: :environment do
      require "jxc_rails/variant_processor_check"
      JxcRails::VariantProcessorCheck.smoke!(logger: Rails.logger)
      puts "[jxc_rails] variant_processor:smoke passed"
    end
  end
end

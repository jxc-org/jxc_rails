# frozen_string_literal: true

namespace :jxc_rails do
  namespace :storage do
    desc "HEAD the R2 bucket and put/get/delete a probe object under _jxc_rails_probe/; prints PASS or FAIL"
    task check: :environment do
      require "jxc_rails/r2_storage"
      exit(1) unless JxcRails::R2Storage.probe!
    end

    desc "Add the r2 service to config/storage.yml and aws-sdk-s3 to the Gemfile (idempotent)"
    task :install do
      require "jxc_rails/r2_storage"
      JxcRails::R2Storage.install!(root: Rails.root.to_s)
    end
  end
end

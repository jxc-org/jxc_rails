# frozen_string_literal: true

require "securerandom"

module JxcRails
  # Cloudflare R2 as the standard Active Storage backend for jxc-org apps.
  #
  # Three pieces, all keyed off the +r2+ service name:
  #
  # - {STORAGE_YML}: the service block {.install!} appends to an app's
  #   +config/storage.yml+ (gigq's hand-written block, generalised to env vars).
  # - {.run!}: boot check, wired by the Railtie like VariantProcessorCheck. When
  #   +config.active_storage.service+ is +:r2+ it raises at boot if +aws-sdk-s3+
  #   is not in the bundle or any of {ENV_VARS} is missing/blank.
  # - {.probe!}: the +jxc_rails:storage:check+ operator task — HEAD the bucket,
  #   then put/get/delete a small object under {PROBE_PREFIX}.
  #
  # Nothing here ever prints a credential value.
  module R2Storage
    SERVICE_NAME = "r2"
    ENV_VARS = %w[R2_ACCOUNT_ID R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY R2_BUCKET].freeze
    SECRET_ENV_VARS = %w[R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY].freeze
    PROBE_PREFIX = "_jxc_rails_probe/"
    PROBE_BODY = "jxc_rails storage probe"
    GEMFILE_LINE = %(gem "aws-sdk-s3", require: false)

    # R2 rejects the checksums newer aws-sdk-s3 versions send by default, hence
    # both checksum settings pinned to when_required.
    STORAGE_YML = <<~YAML
      r2:
        service: S3
        access_key_id: <%= ENV["R2_ACCESS_KEY_ID"] %>
        secret_access_key: <%= ENV["R2_SECRET_ACCESS_KEY"] %>
        bucket: <%= ENV["R2_BUCKET"] %>
        region: auto
        endpoint: https://<%= ENV["R2_ACCOUNT_ID"] %>.r2.cloudflarestorage.com
        request_checksum_calculation: when_required
        response_checksum_validation: when_required
    YAML

    class << self
      # Boot-time assertion. Returns nil; raises JxcRails::ConfigurationError when
      # the R2 service is selected but can't work.
      def run!(service: configured_service, env: ENV, gem_present: VariantProcessorCheck.method(:gem_present?))
        message = problem(service: service, env: env, gem_present: gem_present)
        raise JxcRails::ConfigurationError, "[jxc_rails] #{message}" if message
      end

      # Pure decision logic. Returns an error message String, else nil. Messages
      # name variables, never their values.
      def problem(service:, env:, gem_present:)
        return nil unless service.to_s == SERVICE_NAME

        unless gem_present.call("aws-sdk-s3")
          return "config.active_storage.service is :r2 but aws-sdk-s3 is not in the bundle. " \
                 "Add `#{GEMFILE_LINE}` to your Gemfile."
        end
        # Docker builds run assets:precompile with SECRET_KEY_BASE_DUMMY and no
        # runtime secrets; the R2 credentials only exist in the running pod.
        return nil if env["SECRET_KEY_BASE_DUMMY"].present?

        missing = ENV_VARS.select { |name| env[name].blank? }
        return nil if missing.empty?

        "config.active_storage.service is :r2 but #{missing.join(", ")} " \
          "#{missing.one? ? "is" : "are"} missing or blank."
      end

      # Read from app.config, not ActiveStorage::Blob.service, so it is settled
      # regardless of after_initialize ordering (see VariantProcessorCheck).
      def configured_service(app: rails_application)
        return nil unless app&.config.respond_to?(:active_storage)

        app.config.active_storage.service
      end

      # Operator check. Prints PASS or FAIL with the error class; returns a
      # boolean. Any credential value that leaks into an error message is redacted.
      def probe!(service: nil, out: $stdout, env: ENV)
        service ||= ActiveStorage::Blob.services.fetch(SERVICE_NAME.to_sym)
        client = service.client.client
        bucket = service.bucket.name
        key = "#{PROBE_PREFIX}#{SecureRandom.hex(8)}"

        client.head_bucket(bucket: bucket)
        client.put_object(bucket: bucket, key: key, body: PROBE_BODY)
        begin
          body = client.get_object(bucket: bucket, key: key).body.read
        ensure
          client.delete_object(bucket: bucket, key: key)
        end
        raise "probe object read back #{body.bytesize} bytes, expected #{PROBE_BODY.bytesize}" unless body == PROBE_BODY

        out.puts "[jxc_rails] storage:check PASS bucket=#{bucket}"
        true
      rescue StandardError => e
        out.puts "[jxc_rails] storage:check FAIL #{e.class}: #{redact(e.message, env)}"
        false
      end

      # Adds the r2 block to config/storage.yml and aws-sdk-s3 to the Gemfile,
      # each only if absent. Idempotent.
      def install!(root:, out: $stdout)
        append_unless(File.join(root, "config/storage.yml"), /^r2:/, STORAGE_YML, out)
        append_unless(File.join(root, "Gemfile"), /^\s*gem\s+["']aws-sdk-s3["']/, "#{GEMFILE_LINE}\n", out)
      end

      private

      def append_unless(path, pattern, text, out)
        existing = File.exist?(path) ? File.read(path) : ""
        return out.puts("[jxc_rails] #{path}: already set up") if existing.match?(pattern)

        separator = if existing.empty? then ""
                    elsif existing.end_with?("\n") then "\n"
                    else "\n\n"
                    end
        File.write(path, "#{separator}#{text}", mode: "a")
        out.puts "[jxc_rails] #{path}: added r2 setup"
      end

      def redact(message, env)
        SECRET_ENV_VARS.filter_map { |name| env[name].presence }
                       .reduce(message.to_s) { |msg, secret| msg.gsub(secret, "[FILTERED]") }
      end

      def rails_application
        Rails.application if defined?(Rails) && Rails.respond_to?(:application)
      end
    end
  end
end

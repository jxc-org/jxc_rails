# frozen_string_literal: true

require "erb"
require "stringio"
require "tmpdir"
require "yaml"
require "jxc_rails/r2_storage"

RSpec.describe JxcRails::R2Storage do
  # Obviously fake values; nothing here is a real credential.
  let(:full_env) do
    {
      "R2_ACCOUNT_ID" => "fake-account",
      "R2_ACCESS_KEY_ID" => "FAKE-ACCESS-KEY-ID",
      "R2_SECRET_ACCESS_KEY" => "FAKE-SECRET-ACCESS-KEY",
      "R2_BUCKET" => "fake-bucket"
    }
  end
  let(:with_sdk) { ->(name) { name == "aws-sdk-s3" } }
  let(:without_sdk) { ->(_name) { false } }

  describe ".run!" do
    it "boots when the r2 service is selected and all four env vars are set" do
      expect { described_class.run!(service: :r2, env: full_env, gem_present: with_sdk) }.not_to raise_error
    end

    described_class::ENV_VARS.each do |name|
      [nil, " "].each do |value|
        it "raises naming #{name} when it is #{value.inspect}, without printing any value" do
          env = full_env.merge(name => value)

          expect { described_class.run!(service: :r2, env: env, gem_present: with_sdk) }
            .to raise_error(JxcRails::ConfigurationError) { |error|
              expect(error.message).to include(name)
              full_env.each_value { |secret| expect(error.message).not_to include(secret) }
            }
        end
      end
    end

    it "raises when aws-sdk-s3 is not in the bundle" do
      expect { described_class.run!(service: :r2, env: full_env, gem_present: without_sdk) }
        .to raise_error(JxcRails::ConfigurationError, /aws-sdk-s3/)
    end

    it "accepts the service as a string" do
      expect { described_class.run!(service: "r2", env: {}, gem_present: with_sdk) }
        .to raise_error(JxcRails::ConfigurationError, /R2_ACCOUNT_ID/)
    end

    it "checks nothing for a non-R2 service" do
      expect { described_class.run!(service: :local, env: {}, gem_present: without_sdk) }.not_to raise_error
    end

    it "checks nothing when the app has no Active Storage config" do
      app = Struct.new(:config).new(Object.new)
      expect(described_class.configured_service(app: app)).to be_nil
    end

    it "skips the env vars during assets:precompile but still requires aws-sdk-s3" do
      env = { "SECRET_KEY_BASE_DUMMY" => "1" }

      expect { described_class.run!(service: :r2, env: env, gem_present: with_sdk) }.not_to raise_error
      expect { described_class.run!(service: :r2, env: env, gem_present: without_sdk) }
        .to raise_error(JxcRails::ConfigurationError, /aws-sdk-s3/)
    end

    it "reads the service from app.config" do
      active_storage = Struct.new(:service).new(:r2)
      app = Struct.new(:config).new(Struct.new(:active_storage).new(active_storage))

      expect(described_class.configured_service(app: app)).to eq(:r2)
    end
  end

  describe "STORAGE_YML" do
    it "renders gigq's R2 settings from the env" do
      stub_const("ENV", full_env)
      rendered = YAML.safe_load(ERB.new(described_class::STORAGE_YML).result)

      expect(rendered).to eq(
        "r2" => {
          "service" => "S3",
          "access_key_id" => "FAKE-ACCESS-KEY-ID",
          "secret_access_key" => "FAKE-SECRET-ACCESS-KEY",
          "bucket" => "fake-bucket",
          "region" => "auto",
          "endpoint" => "https://fake-account.r2.cloudflarestorage.com",
          "request_checksum_calculation" => "when_required",
          "response_checksum_validation" => "when_required"
        }
      )
    end
  end

  describe ".probe!" do
    let(:client) { double("Aws::S3::Client") }
    let(:service) do
      Struct.new(:client, :bucket).new(Struct.new(:client).new(client), Struct.new(:name).new("fake-bucket"))
    end
    let(:out) { StringIO.new }
    let(:stored) { {} }

    before do
      allow(client).to receive(:head_bucket)
      allow(client).to receive(:put_object) { |key:, body:, **| stored[key] = body }
      allow(client).to receive(:get_object) { |key:, **| Struct.new(:body).new(StringIO.new(stored.fetch(key))) }
      allow(client).to receive(:delete_object)
    end

    it "prints PASS after a HEAD and a put/get/delete under the probe prefix" do
      expect(described_class.probe!(service: service, out: out, env: full_env)).to be(true)

      expect(out.string).to include("PASS")
      expect(client).to have_received(:head_bucket).with(bucket: "fake-bucket")
      expect(stored.keys).to contain_exactly(start_with("_jxc_rails_probe/"))
      expect(client).to have_received(:delete_object).with(bucket: "fake-bucket", key: stored.keys.first)
    end

    it "prints FAIL with the error class when the HEAD fails, and never a secret value" do
      stub_const("Aws::S3::Errors::Forbidden", Class.new(StandardError))
      allow(client).to receive(:head_bucket)
        .and_raise(Aws::S3::Errors::Forbidden, "denied for FAKE-ACCESS-KEY-ID / FAKE-SECRET-ACCESS-KEY")

      expect(described_class.probe!(service: service, out: out, env: full_env)).to be(false)

      expect(out.string).to include("FAIL", "Aws::S3::Errors::Forbidden")
      expect(out.string).not_to include("FAKE-ACCESS-KEY-ID", "FAKE-SECRET-ACCESS-KEY")
      expect(client).not_to have_received(:put_object)
    end
  end

  describe ".install!" do
    it "adds the r2 block and aws-sdk-s3, and is a no-op the second time" do
      Dir.mktmpdir do |root|
        Dir.mkdir(File.join(root, "config"))
        File.write(File.join(root, "config/storage.yml"), "local:\n  service: Disk\n  root: storage\n")
        File.write(File.join(root, "Gemfile"), %(source "https://rubygems.org"\n\ngem "rails"))

        described_class.install!(root: root, out: StringIO.new)
        storage = File.read(File.join(root, "config/storage.yml"))
        gemfile = File.read(File.join(root, "Gemfile"))

        expect(YAML.safe_load(ERB.new(storage).result).keys).to eq(%w[local r2])
        expect(gemfile).to end_with(%(gem "rails"\n\ngem "aws-sdk-s3", require: false\n))

        described_class.install!(root: root, out: StringIO.new)

        expect(File.read(File.join(root, "config/storage.yml"))).to eq(storage)
        expect(File.read(File.join(root, "Gemfile"))).to eq(gemfile)
      end
    end
  end
end

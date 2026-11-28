# frozen_string_literal: true

require "spec_helper"
require "rails"
require "support/sqlite_memory"
require "action_controller"
require "active_job"
require "action_push_native"
require "webmock/rspec"
require "httpx/adapters/webmock"

# The engine's models load via its app/ paths, which there is no app to add here.
models = File.join(Gem.loaded_specs.fetch("action_push_native").full_gem_path, "app/models/action_push_native")
%w[record device].each { |f| require File.join(models, f) }

ActiveRecord::Schema.define do
  create_table(:push_users)
  create_table(:action_push_native_devices) do |t|
    t.string :name
    t.string :platform, null: false
    t.string :token, null: false
    t.belongs_to :owner, polymorphic: true
    t.timestamps
  end
end

class PushUser < ActiveRecord::Base; end

class ApplicationPushDevice < ActionPushNative::Device
  include JxcRails::Push::Model
end

class PushDevicesController < ActionController::Base
  include JxcRails::Push::ControllerConcern

  class_attribute :user

  def current_user = self.class.user
end

RSpec.describe JxcRails::Push do
  let(:alice) { PushUser.create! }
  let(:bob) { PushUser.create! }
  let(:notification) { ActionPushNative::Notification.new(title: "Hi", body: "Sensitive Child Name") }
  let(:apple_config) do
    { key_id: "KEY", team_id: "TEAM", topic: "org.jxc.test",
      encryption_key: OpenSSL::PKey::EC.generate("prime256v1").to_pem }
  end
  let(:apns_url) { "https://api.push.apple.com/3/device/tok-1" }

  let(:log) { StringIO.new }

  around do |example|
    previous = Rails.logger
    Rails.logger = Logger.new(log) # no app here, so no logger for action_push_native either
    example.run
  ensure
    Rails.logger = previous
  end

  before { allow(ActionPushNative).to receive(:config).and_return({ apple: apple_config }) }
  after { [ApplicationPushDevice, PushUser].each(&:delete_all) }

  describe JxcRails::Push::Model do
    describe ".register" do
      it "leaves one device, owned by the new user, when a token changes hands" do
        ApplicationPushDevice.register(owner: alice, token: "tok-1")
        ApplicationPushDevice.register(owner: bob, token: "tok-1")

        expect(ApplicationPushDevice.where(token: "tok-1").map(&:owner)).to eq([bob])
      end

      it "drops the previous owner's device name when the token moves without a name" do
        ApplicationPushDevice.register(owner: alice, token: "tok-1", name: "Alice's iPhone")

        expect(ApplicationPushDevice.register(owner: bob, token: "tok-1").name).to be_nil
      end

      it "keeps the name when the same owner re-registers without one" do
        ApplicationPushDevice.register(owner: alice, token: "tok-1", name: "iPhone")

        expect(ApplicationPushDevice.register(owner: alice, token: "tok-1").reload.name).to eq("iPhone")
      end

      it "is idempotent for the same owner" do
        2.times { ApplicationPushDevice.register(owner: alice, token: "tok-1") }
        expect(ApplicationPushDevice.count).to eq(1)
      end
    end

    describe ".unregister" do
      let!(:mine) { ApplicationPushDevice.register(owner: alice, token: "tok-1") }
      let!(:other) { ApplicationPushDevice.register(owner: alice, token: "tok-2") }

      it "destroys only the device with that token" do
        ApplicationPushDevice.unregister(owner: alice, token: "tok-1")
        expect(ApplicationPushDevice.all).to eq([other])
      end

      it "accepts a device id" do
        ApplicationPushDevice.unregister(owner: alice, id: mine.id)
        expect(ApplicationPushDevice.all).to eq([other])
      end

      it "leaves another user's device, and everything when given neither token nor id" do
        ApplicationPushDevice.unregister(owner: bob, token: "tok-1")
        ApplicationPushDevice.unregister(owner: alice)
        expect(ApplicationPushDevice.count).to eq(2)
      end
    end

    describe "#push" do
      let!(:device) { ApplicationPushDevice.register(owner: alice, token: "tok-1") }

      it "keeps the device on a 200" do
        stub = stub_request(:post, apns_url).to_return(status: 200)
        device.push(notification)
        expect(stub).to have_been_requested
        expect(ApplicationPushDevice.count).to eq(1)
      end

      it "destroys the device on a 410" do
        stub_request(:post, apns_url).to_return(status: 410, body: { reason: "Unregistered" }.to_json)
        device.push(notification)
        expect(ApplicationPushDevice.count).to eq(0)
      end

      it "destroys the device on BadDeviceToken" do
        stub_request(:post, apns_url).to_return(status: 400, body: { reason: "BadDeviceToken" }.to_json)
        device.push(notification)
        expect(ApplicationPushDevice.count).to eq(0)
      end

      context "without APNs credentials" do
        it "skips the send with one log line holding no token or payload" do
          allow(ActionPushNative).to receive(:config).and_return({ apple: apple_config.merge(encryption_key: nil) })

          expect { device.push(notification) }.not_to raise_error
          expect(a_request(:post, /apple/)).not_to have_been_made
          expect(log.string.lines.size).to eq(1)
          expect(log.string).not_to include("tok-1", "Sensitive Child Name")
          expect(ApplicationPushDevice.count).to eq(1)
        end

        it "skips when there is no push config at all" do
          allow(ActionPushNative).to receive(:config).and_raise("ActionPushNative: config/push.yml not found")

          expect { device.push(notification) }.not_to raise_error
          expect(log.string.lines.size).to eq(1)
        end

        it "skips when push.yml has no block for the platform" do
          allow(ActionPushNative).to receive(:config).and_return({ google: {} })

          expect { device.push(notification) }.not_to raise_error
          expect(log.string.lines.size).to eq(1)
        end
      end

      context "with a malformed config/push.yml" do
        it "raises instead of reporting push as not configured" do
          allow(ActionPushNative).to receive(:config) { YAML.load("apple: [key_id: KEY") }

          expect { device.push(notification) }.to raise_error(Psych::SyntaxError)
          expect(log.string).not_to include("not configured")
        end
      end
    end
  end

  describe JxcRails::Push::ControllerConcern do
    def call(user, method, path, params = {})
      PushDevicesController.user = user
      env = Rack::MockRequest.env_for(path, method: method, params: params)
      action = method == "POST" ? :create : :destroy
      PushDevicesController.action(action).call(env.merge("action_dispatch.request.path_parameters" => { id: path[/\d+/] }.compact))
    end

    it "registers the signed-in user's token" do
      status, = call(alice, "POST", "/devices", token: "tok-1", name: "iPhone")
      expect(status).to eq(201)
      expect(ApplicationPushDevice.find_by!(token: "tok-1").owner).to eq(alice)
    end

    it "rejects a request without a user" do
      expect(call(nil, "POST", "/devices", token: "tok-1")[0]).to eq(401)
      expect(ApplicationPushDevice.count).to eq(0)
    end

    it "rejects an unknown platform" do
      expect(call(alice, "POST", "/devices", token: "tok-1", platform: "palm")[0]).to eq(422)
    end

    it "destroys the caller's own device" do
      device = ApplicationPushDevice.register(owner: alice, token: "tok-1")
      expect(call(alice, "DELETE", "/devices/#{device.id}")[0]).to eq(204)
      expect(ApplicationPushDevice.count).to eq(0)
    end

    it "returns 404 for another user's device, which survives" do
      device = ApplicationPushDevice.register(owner: alice, token: "tok-1")
      expect(call(bob, "DELETE", "/devices/#{device.id}")[0]).to eq(404)
      expect(ApplicationPushDevice.count).to eq(1)
    end
  end
end

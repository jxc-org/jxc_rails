# frozen_string_literal: true

require "spec_helper"
require "support/sqlite_memory"
require "action_controller"
require "action_view"
require "active_support/testing/time_helpers"

ActiveRecord::Schema.define { create_table(:tz_users) { |t| t.string :time_zone } }

class TzUser < ActiveRecord::Base
  include JxcRails::TimeZone::Model
end

class TzController < ActionController::Base
  include JxcRails::TimeZone::ControllerConcern

  class_attribute :user

  def current_user = self.class.user

  def index
    render plain: Date.current.to_s
  end
end

RSpec.describe JxcRails::TimeZone do
  include ActiveSupport::Testing::TimeHelpers

  after { TzUser.delete_all }

  def ny(*args) = Time.find_zone("America/New_York").local(*args)

  describe JxcRails::TimeZone::Model do
    it "rejects an invalid zone id" do
      expect(TzUser.new(time_zone: "Mars/Olympus")).not_to be_valid
      expect(TzUser.new(time_zone: "Eastern Time (US & Canada)")).not_to be_valid
    end

    it "accepts a valid IANA id and nil" do
      expect(TzUser.new(time_zone: "Pacific/Honolulu")).to be_valid
      expect(TzUser.new(time_zone: nil)).to be_valid
    end

    it "falls back to the default when the stored zone is not a valid IANA id" do
      expect(TzUser.new(time_zone: "Mars/Olympus").effective_time_zone).to eq("America/New_York")
    end

    it "returns the stored zone, else the configured default" do
      expect(TzUser.new(time_zone: "Pacific/Honolulu").effective_time_zone).to eq("Pacific/Honolulu")
      expect(TzUser.new.effective_time_zone).to eq("America/New_York")

      JxcRails.config.time_zone.default = "Europe/London"
      expect(TzUser.new.effective_time_zone).to eq("Europe/London")
    ensure
      JxcRails.reset_configuration!
    end
  end

  describe ".use_for" do
    def date_for(user) = described_class.use_for(user) { Date.current }

    it "makes Date.current follow the user's zone" do
      honolulu = TzUser.new(time_zone: "Pacific/Honolulu")
      new_york = TzUser.new(time_zone: "America/New_York")

      travel_to(ny(2026, 3, 10, 23, 30)) do
        expect(date_for(honolulu)).to eq(Date.new(2026, 3, 10))
        expect(date_for(new_york)).to eq(Date.new(2026, 3, 10))
      end
      travel_to(ny(2026, 3, 11, 1, 30)) do
        expect(date_for(honolulu)).to eq(Date.new(2026, 3, 10))
        expect(date_for(new_york)).to eq(Date.new(2026, 3, 11))
      end
    end

    it "falls back to the default for a nil zone or nil user" do
      travel_to(ny(2026, 3, 11, 1, 30)) do
        expect(date_for(TzUser.new)).to eq(Date.new(2026, 3, 11))
        expect(date_for(nil)).to eq(Date.new(2026, 3, 11))
      end
    end

    it "falls back to the default for an invalid stored zone instead of raising" do
      travel_to(ny(2026, 3, 11, 1, 30)) do
        expect(date_for(TzUser.new(time_zone: "Mars/Olympus"))).to eq(Date.new(2026, 3, 11))
      end
    end

    it "restores the previous zone afterwards" do
      before = Time.zone
      described_class.use_for(TzUser.new(time_zone: "Pacific/Honolulu")) { nil }
      expect(Time.zone).to eq(before)
    end
  end

  describe JxcRails::TimeZone::ControllerConcern do
    def get(user, cookie: nil)
      TzController.user = user
      env = Rack::MockRequest.env_for("/", "HTTP_COOKIE" => cookie)
      TzController.action(:index).call(env)
    end

    it "fills a nil zone from a valid cookie" do
      user = TzUser.create!
      get(user, cookie: "jxc_tz=Pacific%2FHonolulu")
      expect(user.reload.time_zone).to eq("Pacific/Honolulu")
    end

    it "ignores an invalid cookie value" do
      user = TzUser.create!
      get(user, cookie: "jxc_tz=Mars%2FOlympus")
      expect(user.reload.time_zone).to be_nil
    end

    it "never changes a stored zone" do
      user = TzUser.create!(time_zone: "America/New_York")
      get(user, cookie: "jxc_tz=Pacific%2FHonolulu")
      expect(user.reload.time_zone).to eq("America/New_York")
    end

    it "does nothing when signed out" do
      expect(get(nil, cookie: "jxc_tz=Pacific%2FHonolulu")[0]).to eq(200)
    end

    it "runs the action in the user's zone, defaulting when nil" do
      honolulu = TzUser.create!(time_zone: "Pacific/Honolulu")
      travel_to(ny(2026, 3, 11, 1, 30)) do
        expect(get(honolulu)[2].body).to eq("2026-03-10")
        expect(get(TzUser.create!)[2].body).to eq("2026-03-11")
        expect(get(nil)[2].body).to eq("2026-03-11")
      end
    end

    it "runs the action in the default zone when the stored zone is invalid" do
      user = TzUser.create!
      user.update_column(:time_zone, "Mars/Olympus")
      travel_to(ny(2026, 3, 11, 1, 30)) do
        expect(get(user)[2].body).to eq("2026-03-11")
      end
    end

    it "uses a zone captured from the cookie in the same request" do
      user = TzUser.create!
      travel_to(ny(2026, 3, 11, 1, 30)) do
        expect(get(user, cookie: "jxc_tz=Pacific%2FHonolulu")[2].body).to eq("2026-03-10")
      end
    end
  end

  describe JxcRails::TimeZone::ViewHelper do
    let(:view) do
      Class.new do
        include ActionView::Helpers::TagHelper
        include ActionView::Helpers::JavaScriptHelper
        include JxcRails::TimeZone::ViewHelper

        attr_accessor :output_buffer, :current_user

        def content_security_policy_nonce = "n0nce"
      end.new
    end

    it "renders the capture script while the zone is nil" do
      view.current_user = TzUser.new
      html = view.jxc_time_zone_capture_tag
      expect(html).to start_with("<script")
      expect(html).to include("jxc_tz", "Intl.DateTimeFormat().resolvedOptions().timeZone")
    end

    it "carries the CSP nonce" do
      view.current_user = TzUser.new
      expect(view.jxc_time_zone_capture_tag).to include('nonce="n0nce"')
    end

    it "renders an empty string when a zone is stored" do
      view.current_user = TzUser.new(time_zone: "America/New_York")
      expect(view.jxc_time_zone_capture_tag).to eq("")
    end

    it "renders an empty string when signed out" do
      view.current_user = nil
      expect(view.jxc_time_zone_capture_tag).to eq("")
    end
  end
end

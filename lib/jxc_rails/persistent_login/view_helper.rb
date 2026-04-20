# frozen_string_literal: true

module JxcRails
  module PersistentLogin
    # Adds small view helpers for templates that want to hide the
    # "remember me" checkbox on Hotwire Native clients, since persistent
    # login is automatic there.
    module ViewHelper
      # True when the "remember me" checkbox should be visible — i.e. the
      # current request is NOT from a Hotwire Native client.
      def show_remember_me_checkbox?
        !turbo_native_app?
      end
    end
  end
end

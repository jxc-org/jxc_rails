# frozen_string_literal: true

module JxcRails
  module PersistentLogin
    autoload :Sessions,      "jxc_rails/persistent_login/sessions"
    autoload :Registrations, "jxc_rails/persistent_login/registrations"
    autoload :ViewHelper,    "jxc_rails/persistent_login/view_helper"
  end
end

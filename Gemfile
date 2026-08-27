# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "irb"
gem "rake", "~> 13.0"
gem "rspec", "~> 3.0"
gem "rubocop", "~> 1.86"

group :test do
  # capybara + selenium are what an app brings to system specs; the gem carries
  # them in test only so the driver-plumbing spec can assert on the arguments
  # Rails actually hands to Chrome (no browser is launched).
  gem "capybara", "~> 3.40"
  gem "combustion", "~> 1.5"
  gem "devise"
  gem "rails", ">= 7.1"
  gem "selenium-webdriver", "~> 4.44"
  gem "sqlite3"
end

# frozen_string_literal: true

require "active_support/concern"

module JxcRails
  module ShortCode
    # Extended onto ActiveRecord::Base by the railtie to provide the
    # `has_short_code` class macro.
    #
    #   class Gift < ApplicationRecord
    #     has_short_code :code, length: 8
    #   end
    #
    #   class Show < ApplicationRecord
    #     has_short_code :join_code, length: 5, alphabet: :uppercase_crockford, to_param: false
    #   end
    #
    # Options:
    # - `length:`    digits in the generated code (default: config)
    # - `alphabet:`  symbol (see ShortCode::ALPHABETS) or custom string
    # - `on:`        :create (default) or :validation — when to assign
    # - `to_param:`  true (default) to override `to_param`, false to leave alone
    # - `finder:`    method name for `find_by_<field>!` (default: "find_by_#{field}!")
    module Concern
      def has_short_code(field, length: nil, alphabet: :crockford, on: :create, to_param: true, finder: nil)
        generator = Generator.new(alphabet: alphabet, length: length)

        validates field, uniqueness: true, allow_nil: true

        hook = on == :validation ? :before_validation : :before_create
        send(hook, on: on == :validation ? :create : nil) do
          next if self[field].present?

          loop do
            candidate = generator.call
            unless self.class.exists?(field => candidate)
              self[field] = candidate
              break
            end
          end
        end

        define_method(:to_param) { self[field] } if to_param

        finder_name = finder || "find_by_#{field}!"
        define_singleton_method(finder_name) do |value|
          find_by!(field => value)
        end
      end
    end
  end
end

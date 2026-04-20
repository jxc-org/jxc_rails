# frozen_string_literal: true

module JxcRails
  module ShortCode
    ALPHABETS = {
      crockford:           "23456789abcdefghjkmnpqrstvwxyz",
      uppercase_crockford: "ABCDEFGHJKMNPQRSTUVWXYZ23456789",
      hex:                 "0123456789abcdef"
    }.freeze

    autoload :Concern,   "jxc_rails/short_code/concern"
    autoload :Generator, "jxc_rails/short_code/generator"

    def self.alphabet(name_or_string)
      return name_or_string if name_or_string.is_a?(String)
      ALPHABETS.fetch(name_or_string) do
        raise ArgumentError, "Unknown alphabet: #{name_or_string.inspect}. Known: #{ALPHABETS.keys.inspect}, or pass a custom string."
      end
    end
  end
end

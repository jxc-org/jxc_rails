# frozen_string_literal: true

require "securerandom"

module JxcRails
  module ShortCode
    # Generates random short codes using a configurable alphabet and length.
    # Not thread-unsafe per se, but uses SecureRandom for randomness so
    # instances are disposable.
    class Generator
      attr_reader :alphabet, :length

      def initialize(alphabet: :crockford, length: nil)
        @alphabet = ShortCode.alphabet(alphabet).chars
        @length   = length || JxcRails.configuration.short_code.default_length
      end

      def call
        Array.new(@length) { @alphabet.sample(random: SecureRandom) }.join
      end
    end
  end
end

require "active_record"
require "securerandom"
require_relative "happy_slugs/version"
require_relative "happy_slugs/words"

module HappySlugs
  class ExhaustedError < StandardError; end

  DEFAULT_PATTERN = %i[adjective noun verb].freeze
  BATCH_SIZE = 10

  module SlugGenerator
    extend ActiveSupport::Concern

    included do
      before_create :generate_happy_slug
      scope :with_happy_slug_in, ->(slugs) { where(happy_slug_attribute => slugs) }
    end

    def happy_slug
      self[happy_slug_attribute]
    end

    private

    def generate_happy_slug
      if happy_slug.nil?
        happy_slug_patterns.each do |pattern|
          candidates = BATCH_SIZE.times.map { build_happy_slug(pattern) }
          existing = self.class.with_happy_slug_in(candidates).pluck(happy_slug_attribute)

          available = candidates - existing

          if available.any?
            self[happy_slug_attribute] = available.sample
            break
          end
        end
      end

      if happy_slug.nil?
        raise ExhaustedError, "could not generate a unique slug for #{self.class.name}"
      end
    end

    def happy_slug_patterns
      [happy_slug_pattern, happy_slug_pattern + [:suffix]].uniq
    end

    def build_happy_slug(pattern)
      pattern.map { |segment|
        if segment == :suffix
          SecureRandom.alphanumeric(happy_slug_suffix_length).downcase
        else
          Words.sample(segment)
        end
      }.join(happy_slug_separator)
    end

    class_methods do
      def backfill_happy_slugs
        count = 0
        where(happy_slug_attribute => nil).find_each do |record|
          record.send(:generate_happy_slug)
          record.update_column(happy_slug_attribute, record[happy_slug_attribute])
          count += 1
        rescue ActiveRecord::RecordNotUnique => e
          raise unless e.message.include?(happy_slug_attribute.to_s)
          record[happy_slug_attribute] = nil
          retry
        end
        count
      end
    end
  end

  def has_happy_slugs(attribute = :slug, pattern: DEFAULT_PATTERN, separator: "-", suffix_length: 4)
    class_attribute :happy_slug_attribute, default: attribute
    class_attribute :happy_slug_pattern, default: pattern
    class_attribute :happy_slug_separator, default: separator
    class_attribute :happy_slug_suffix_length, default: suffix_length

    include SlugGenerator
  end
end

ActiveSupport.on_load(:active_record) do
  extend HappySlugs
end

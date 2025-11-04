# typed: true
# frozen_string_literal: true

require "yaml"
require "date"
require "time"

module Adapter
  # rubocop:disable Metrics/ClassLength
  class AdventCalendar
    END_DATE = Date.parse("2025-12-25")
    DATA_FILE =
      if Rails.env.test?
        Rails.root.join("test", "data", "test_advent_calendar.yml")
      else
        Rails.root.join("lib", "data", "advent_calendar.yml")
      end
    VOUCHER_FILE = Rails.root.join("lib", "data", "advent_calendar_voucher.yml")
    VOUCHER_MILESTONES = [3, 13, 33, 53, 73, 94].freeze

    NoEligibleDrawsError = Class.new(StandardError)
    VoucherNotFoundError = Class.new(StandardError)
    VoucherAlreadyRedeemedError = Class.new(StandardError)

    DayEntry = Data.define(:checked_in, :stars) do
      def checked_in?
        !!checked_in
      end

      def stars_amount
        [stars.to_i, 0].max
      end

      def serialize
        {
          "checked_in" => checked_in?,
          "stars" => stars_amount
        }
      end
    end

    VoucherAward = Data.define(:id, :title, :details, :awarded_at, :redeemed_at) do
      def redeemed?
        redeemed_at.present? && !redeemed_at.to_s.strip.empty?
      end

      def serialize
        {
          "id" => id,
          "title" => title.to_s,
          "details" => details.to_s,
          "awarded_at" => awarded_at,
          "redeemed_at" => redeemed_at
        }
      end

      def to_h
        {
          id: id,
          title: title,
          details: details,
          awarded_at: awarded_at,
          redeemed_at: redeemed_at,
          redeemed: redeemed?
        }
      end
    end

    attr_reader :total_stars, :total_check_ins

    def self.on(day)
      new(day)
    end

    def initialize(day, data_file: DATA_FILE)
      @day = day.to_date
      @data_file = data_file

      state = load_state(@data_file)
      @calendar_data = state.fetch(:days)
      @voucher_awards = state.fetch(:voucher_awards)
      @voucher_sequence = state.fetch(:voucher_sequence)

      ensure_day_entry!
      sync_totals!
    end

    def check_in
      return if checked_in?

      @calendar_data[@day] = DayEntry.new(true, 1)
      sync_totals!
      persist_state!
    end

    # This is for development purpose
    def reset_check_in
      entry = day_entry
      return unless entry.checked_in? || entry.stars_amount.positive?

      @calendar_data[@day] = DayEntry.new(false, 0)
      sync_totals!
      persist_state!
    end

    def days_left
      (END_DATE - @day).to_i
    end

    def checked_in?
      day_entry.checked_in?
    end

    def prompt
      checked_in? ? "Wah. You are absolutely right" : "Time to check in"
    end

    def template
      checked_in? ? :after : :before
    end

    def draws_unlocked
      VOUCHER_MILESTONES.count { |threshold| @total_stars >= threshold }
    end

    def draws_claimed
      @voucher_awards.length
    end

    def draws_available
      [draws_unlocked - draws_claimed, 0].max
    end

    def voucher_awards
      @voucher_awards.map(&:to_h)
    end

    def voucher_milestones
      VOUCHER_MILESTONES
    end

    def next_milestone
      VOUCHER_MILESTONES.find { |threshold| threshold > @total_stars }
    end

    def stars_until_next_milestone
      threshold = next_milestone
      return nil unless threshold

      [threshold - @total_stars, 0].max
    end

    def can_draw_voucher?
      draws_available.positive?
    end

    def draw_voucher!(random: nil, catalog: nil)
      raise NoEligibleDrawsError, "No draw unlocked yet" unless can_draw_voucher?

      rng = random || Random.new
      pool = Array(catalog || voucher_catalog)
      prize = pool.sample(random: rng)
      raise "Voucher catalogue is empty" if prize.nil?

      award = VoucherAward.new(next_voucher_id, prize.fetch(:title), prize.fetch(:details), current_timestamp, nil)

      @voucher_awards << award

      persist_state!
      award
    end

    def redeem_voucher!(voucher_id)
      award = @voucher_awards.find { |entry| entry.id == voucher_id.to_s }
      raise VoucherNotFoundError, "Voucher not found" unless award
      raise VoucherAlreadyRedeemedError, "Voucher already redeemed" if award.redeemed?

      updated = award.with(redeemed_at: current_timestamp)
      @voucher_awards = @voucher_awards.map { |entry| entry.id == updated.id ? updated : entry }
      persist_state!
      updated
    end

    private

    def day_entry
      @calendar_data.fetch(@day)
    end

    def ensure_day_entry!
      @calendar_data[@day] ||= DayEntry.new(false, 0)
    end

    def sync_totals!
      entries = @calendar_data.values
      @total_check_ins = entries.count(&:checked_in?)
      @total_stars = entries.sum(&:stars_amount)
    end

    def persist_state!
      days_payload = @calendar_data
                     .sort_by(&:first)
                     .to_h
                     .transform_values(&:serialize)

      payload = {
        "days" => days_payload,
        "voucher_awards" => @voucher_awards.map(&:serialize),
        "voucher_sequence" => @voucher_sequence
      }

      File.write(@data_file, YAML.dump(payload))
    end

    def load_state(file)
      raise Errno::ENOENT unless File.exist?(file)

      raw = YAML.safe_load(File.read(file), permitted_classes: [Date], symbolize_names: true) || {}
      days_raw = extract_days(raw)
      awards_raw = extract_awards(raw)

      awards = build_awards(awards_raw)

      {
        days: build_calendar(days_raw),
        voucher_awards: awards,
        voucher_sequence: extract_voucher_sequence(raw, awards)
      }
    end

    def extract_days(raw)
      if raw.key?(:days)
        raw[:days] || {}
      elsif raw.key?("days")
        raw["days"] || {}
      else
        raw
      end
    end

    def extract_awards(raw)
      value_for(raw, :voucher_awards) || []
    end

    def build_calendar(raw)
      raw.each_with_object({}) do |(date, attrs), memo|
        memo[coerce_date_key(date)] = DayEntry.new(**coerce_day_attrs(attrs))
      end
    end

    def coerce_day_attrs(attrs)
      return { checked_in: false, stars: 0 } unless attrs.is_a?(Hash)

      {
        checked_in: normalize_boolean(value_for(attrs, :checked_in)),
        stars: normalize_integer(value_for(attrs, :stars))
      }
    end

    def build_awards(raw)
      Array(raw).filter_map { |attrs| build_award_entry(attrs) }
    end

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def build_award_entry(attrs)
      return unless attrs.is_a?(Hash)

      title = value_for(attrs, :title)
      details = value_for(attrs, :details)
      return if title.nil? || title.to_s.strip.empty? || details.nil? || details.to_s.strip.empty?

      awarded_at = value_for(attrs, :awarded_at)
      redeemed_at = value_for(attrs, :redeemed_at)
      id = (value_for(attrs, :id) || SecureRandom.uuid).to_s

      VoucherAward.new(id, title.to_s, details.to_s, (awarded_at || "").to_s, redeemed_at&.to_s)
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    def coerce_date_key(key)
      return key if key.is_a?(Date)

      Date.iso8601(key.to_s)
    rescue ArgumentError
      raise "Malformed yml file"
    end

    def value_for(attrs, key)
      return unless attrs.respond_to?(:[])

      attrs[key] || attrs[key.to_s]
    end

    def normalize_boolean(value)
      case value
      when true, "true", "1", 1 then true
      else
        false
      end
    end

    def normalize_integer(value)
      value.to_i
    end

    def extract_voucher_sequence(raw, awards)
      explicit = value_for(raw, :voucher_sequence)
      return explicit.to_i if explicit

      next_sequence(awards)
    end

    def next_sequence(awards)
      max_numeric = awards.filter_map do |award|
        award.id.to_s[/voucher-(\d+)/, 1]&.to_i
      end.max

      (max_numeric || 0) + 1
    end

    def next_voucher_id
      id = format("voucher-%04d", @voucher_sequence)
      @voucher_sequence += 1
      id
    end

    def voucher_catalog
      @voucher_catalog ||= self.class.voucher_catalog
    end

    def current_timestamp
      (Time.zone ? Time.zone.now : Time.now).iso8601
    end

    class << self
      def voucher_catalog
        raw = YAML.safe_load(File.read(VOUCHER_FILE), symbolize_names: true) || {}
        Array(raw[:items]).map do |item|
          {
            title: item[:title].to_s,
            details: item[:details].to_s
          }
        end
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end

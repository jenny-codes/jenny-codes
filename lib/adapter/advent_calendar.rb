# typed: true
# frozen_string_literal: true

require "yaml"
require "date"
require "time"

module Adapter
  class AdventCalendar
    END_DATE = Date.parse("2025-12-25")
    PUZZLE_ANSWERS_FILE = Rails.root.join("lib", "data", "advent_calendar_puzzle_answers.yml")
    VOUCHER_FILE = Rails.root.join("lib", "data", "advent_calendar_voucher.yml")
    VOUCHER_MILESTONES = [3, 13, 33, 53, 73, 94].freeze

    NoEligibleDrawsError = Class.new(StandardError)
    VoucherNotFoundError = Class.new(StandardError)
    VoucherAlreadyRedeemedError = Class.new(StandardError)

    DayEntry = Data.define(:stars, :puzzle_answer) do
      def stars_amount
        [stars.to_i, 0].max
      end

      def checked_in?
        stars_amount.positive?
      end

      def puzzle_answer_value
        value = puzzle_answer
        return nil if value.nil?

        stripped = value.to_s.strip
        stripped.empty? ? nil : stripped
      end

      def puzzle_answer_matches?(attempt)
        expected = puzzle_answer_value
        return false if expected.nil? || expected.empty?

        attempt.to_s.strip.casecmp?(expected)
      end

      def puzzle_completed?
        stars_amount >= 2
      end
    end

    VoucherPayload = Data.define(:id, :title, :details, :awarded_at, :redeemed_at) do
      def redeemed?
        redeemed_at.present? && !redeemed_at.to_s.strip.empty?
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

    attr_reader :day, :total_stars, :total_check_ins

    def self.on(day)
      new(day)
    end

    def initialize(day)
      @day = day.to_date
      ensure_day_entry!
      refresh_totals!
    end

    def check_in
      record = day_record
      return if record.stars.positive?

      record.update!(stars: 1)
      refresh_totals!
    end

    def reset_check_in
      record = day_record
      return unless record.stars.positive?

      record.update!(stars: 0)
      refresh_totals!
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
      VOUCHER_MILESTONES.count { |threshold| total_stars >= threshold }
    end

    def draws_claimed
      Voucher.count
    end

    def draws_available
      [draws_unlocked - draws_claimed, 0].max
    end

    def puzzle_answer
      day_entry.puzzle_answer_value
    end

    def puzzle_completed?
      day_entry.puzzle_completed?
    end

    def attempt_puzzle!(attempt)
      entry = day_entry
      return false unless entry.puzzle_answer_matches?(attempt)

      award_puzzle_star!(entry)
      true
    end

    def vouchers
      Voucher.order(:created_at, :id).map { |record| wrap_voucher(record).to_h }
    end

    def voucher_milestones
      VOUCHER_MILESTONES
    end

    def next_milestone
      VOUCHER_MILESTONES.find { |threshold| threshold > total_stars }
    end

    def stars_until_next_milestone
      threshold = next_milestone
      return nil unless threshold

      [threshold - total_stars, 0].max
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

      record = Voucher.create!(
        title: prize.fetch(:title),
        details: prize.fetch(:details),
        created_at: current_timestamp,
        updated_at: current_timestamp
      )

      refresh_totals!
      wrap_voucher(record)
    end

    def redeem_voucher!(voucher_id)
      record = find_voucher_record(voucher_id)
      raise VoucherAlreadyRedeemedError, "Voucher already redeemed" if record.redeemed_at.present?

      record.update!(redeemed_at: current_timestamp)
      wrap_voucher(record)
    end

    def puzzle_answers_path
      self.class.puzzle_answers_path
    end

    private

    def day_record
      CalendarDay.find_by!(day: @day)
    end

    def day_entry
      DayEntry.new(day_record.stars, puzzle_answer_for(@day))
    end

    def ensure_day_entry!
      CalendarDay.find_or_create_by!(day: @day) do |record|
        record.stars = 0
      end
    end

    def refresh_totals!
      table = CalendarDay.arel_table
      @total_check_ins = CalendarDay.where(table[:stars].gt(0)).count
      @total_stars = CalendarDay.sum(:stars)
    end

    def award_puzzle_star!(entry)
      return if entry.puzzle_completed?

      record = day_record
      return if record.stars.zero?

      record.update!(stars: 2)
      refresh_totals!
    end

    def puzzle_answer_for(day)
      answers = self.class.puzzle_answers
      answers[day.to_s] || answers[day.iso8601]
    end

    def wrap_voucher(record)
      VoucherPayload.new(
        format_voucher_identifier(record.id),
        record.title,
        record.details,
        format_time(record.created_at),
        format_time(record.redeemed_at)
      )
    end

    def find_voucher_record(identifier)
      numeric_id = identifier.to_s[/voucher-(\d+)/, 1]&.to_i
      raise VoucherNotFoundError, "Voucher not found" if numeric_id.nil? || numeric_id.zero?

      Voucher.find_by(id: numeric_id) || raise(VoucherNotFoundError, "Voucher not found")
    end

    def format_voucher_identifier(id)
      format("voucher-%04d", id)
    end

    def format_time(value)
      value&.iso8601
    end

    def current_timestamp
      (Time.zone ? Time.zone.now : Time.now)
    end

    def voucher_catalog
      @voucher_catalog ||= self.class.voucher_catalog
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

      def puzzle_answers_path
        Pathname.new(ENV.fetch("ADVENT_PUZZLE_ANSWERS_PATH", PUZZLE_ANSWERS_FILE.to_s))
      end

      def puzzle_answers
        @puzzle_answers ||= load_puzzle_answers
      end

      def reload_puzzle_answers!
        @puzzle_answers = nil
      end

      private

      def load_puzzle_answers
        path = puzzle_answers_path
        return {} unless path.exist?

        raw = YAML.safe_load(
          path.read,
          permitted_classes: [Date],
          permitted_symbols: [],
          aliases: false
        ) || {}

        raw.each_with_object({}) do |(date_value, answer), memo|
          date = parse_date(date_value)
          next unless date

          cleaned = answer.to_s.strip
          memo[date.to_s] = cleaned unless cleaned.empty?
        end
      end

      def parse_date(value)
        case value
        when Date
          value
        else
          Date.iso8601(value.to_s)
        end
      rescue ArgumentError
        nil
      end
    end
  end
end

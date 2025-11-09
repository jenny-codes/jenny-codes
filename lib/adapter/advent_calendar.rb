# typed: true
# frozen_string_literal: true

require "yaml"
require "date"
require "time"
require_relative "advent_calendar/store"

module Adapter
  class AdventCalendar
    END_DATE = Date.parse("2025-12-25")
    VOUCHER_MILESTONES = [3, 13, 23, 33, 43, 53, 63, 73, 83, 94].freeze

    NoEligibleDrawsError = Class.new(StandardError)
    VoucherNotFoundError = Class.new(StandardError)
    VoucherAlreadyRedeemedError = Class.new(StandardError)
    VoucherNotRedeemableError = Class.new(StandardError)

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

    VoucherPayload = Data.define(:id, :title, :details, :awarded_at, :redeemable_at, :redeemed_at) do
      def redeemed?
        redeemed_at.present? && !redeemed_at.to_s.strip.empty?
      end

      def redeemable_on
        return nil if redeemable_at.blank?

        Date.iso8601(redeemable_at.to_s)
      rescue ArgumentError
        nil
      end

      def redeemable?(today = Date.current)
        date = redeemable_on
        return true unless date

        date <= today
      end

      def to_h
        {
          id: id,
          title: title,
          details: details,
          awarded_at: awarded_at,
          redeemable_at: redeemable_at,
          redeemed_at: redeemed_at,
          redeemed: redeemed?,
          redeemable: redeemable?
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
      entry = store.fetch_day(@day)
      return if entry && entry["stars"].to_i.positive?

      puzzle_answer = entry ? entry["puzzle_answer"] : nil
      store.write_day(day: @day, stars: 1, puzzle_answer: puzzle_answer)
      refresh_totals!
    end

    def reset_check_in
      entry = store.fetch_day(@day)
      return unless entry && entry["stars"].to_i.positive?

      store.write_day(day: @day, stars: 0, puzzle_answer: entry["puzzle_answer"])
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
      store.all_vouchers.count
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
      store.all_vouchers.map { |record| wrap_voucher(record).to_h }
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
      prize = weighted_prize(pool, rng)

      record = store.append_voucher(
        title: prize.fetch(:title),
        details: prize.fetch(:details),
        awarded_at: current_timestamp.iso8601,
        redeemable_at: prize[:redeemable_at]
      )

      refresh_totals!
      wrap_voucher(record)
    end

    def redeem_voucher!(voucher_id)
      record = find_voucher_record(voucher_id)
      voucher = wrap_voucher(record)

      raise VoucherAlreadyRedeemedError, "Voucher already redeemed" if voucher.redeemed?

      unless voucher.redeemable?
        raise VoucherNotRedeemableError,
              "Voucher not redeemable until #{voucher.redeemable_at || 'a future date'}"
      end

      updated = store.update_voucher(record["id"], redeemed_at: current_timestamp.iso8601)
      wrap_voucher(updated)
    end

    def complete_puzzle!
      return false if day_entry.puzzle_completed?

      data = store.fetch_day(@day)
      return false unless data && data["stars"].to_i.positive?

      store.write_day(day: @day, stars: 2, puzzle_answer: data["puzzle_answer"])
      refresh_totals!
      true
    end

    private

    def store
      Store.instance
    end

    def day_entry
      data = store.fetch_day(@day)
      DayEntry.new(data["stars"], data["puzzle_answer"])
    end

    def ensure_day_entry!
      return if store.fetch_day(@day)

      store.write_day(day: @day, stars: 0, puzzle_answer: nil)
    end

    def refresh_totals!
      days = store.all_days
      @total_check_ins = days.count { |entry| entry["stars"].to_i.positive? }
      @total_stars = days.sum { |entry| entry["stars"].to_i }
    end

    def award_puzzle_star!(entry)
      return if entry.puzzle_completed?

      data = store.fetch_day(@day)
      return if data["stars"].to_i.zero?

      store.write_day(day: @day, stars: 2, puzzle_answer: data["puzzle_answer"])
      refresh_totals!
    end

    def wrap_voucher(record)
      VoucherPayload.new(
        format_voucher_identifier(record["id"]),
        record["title"],
        record["details"],
        format_time(record["awarded_at"]),
        record["redeemable_at"],
        format_time(record["redeemed_at"])
      )
    end

    def find_voucher_record(identifier)
      store.find_voucher(identifier.to_s) || raise(VoucherNotFoundError, "Voucher not found")
    end

    def format_voucher_identifier(id)
      return id if id.to_s.start_with?("voucher-")

      format("voucher-%04d", id.to_i)
    end

    def format_time(value)
      case value
      when Time, DateTime
        value.iso8601
      when String
        value
      else
        value&.to_s
      end
    end

    def current_timestamp
      (Time.zone ? Time.zone.now : Time.now)
    end

    def voucher_catalog
      @voucher_catalog ||= self.class.voucher_catalog
    end

    class << self
      def voucher_catalog
        Store.instance.voucher_options.map do |item|
          {
            title: item["title"].to_s,
            details: item["details"].to_s,
            chance: item["chance"].to_i,
            redeemable_at: item["redeemable_at"].presence
          }
        end
      end
    end

    def weighted_prize(pool, rng)
      raise "Voucher catalogue is empty" if pool.empty?

      total_chance = pool.sum { |item| item[:chance].to_i }
      raise "Voucher chances must sum to 100" unless total_chance == 100

      ticket = rng.rand(total_chance)
      accumulator = 0

      pool.each do |item|
        accumulator += item[:chance].to_i
        return item if ticket < accumulator
      end

      pool.last
    end
  end
end

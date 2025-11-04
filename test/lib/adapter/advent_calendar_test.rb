# typed: false
# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"
require "pathname"
require "securerandom"

module Adapter
  # rubocop:disable Metrics/ClassLength
  class AdventCalendarTest < ActiveSupport::TestCase
    setup do
      @tmpdir = Dir.mktmpdir
      @data_file = Pathname.new(File.join(@tmpdir, "advent_calendar.yml"))
      @day = Date.new(2024, 12, 1)
    end

    teardown do
      FileUtils.remove_entry(@tmpdir) if @tmpdir
    end

    test "raises when data file is missing" do
      assert_raises Errno::ENOENT do
        AdventCalendar.new(@day, data_file: @data_file)
      end
    end

    test "defaults to unchecked day when file empty" do
      write_calendar(days: {})

      calendar = AdventCalendar.new(@day, data_file: @data_file)

      refute_predicate calendar, :checked_in?
      assert_equal 0, calendar.total_stars
      assert_equal 0, calendar.total_check_ins
      assert_equal 0, calendar.draws_unlocked
      assert_equal 0, calendar.draws_available
    end

    test "loads checked in day with stars" do
      write_calendar(
        days: {
          @day => { checked_in: true, stars: 35 }
        },
        awards: [build_award("Dinner date")]
      )

      calendar = AdventCalendar.new(@day, data_file: @data_file)

      assert_predicate calendar, :checked_in?
      assert_equal 35, calendar.total_stars
      assert_equal 1, calendar.total_check_ins
      assert_equal 3, calendar.draws_available + calendar.draws_claimed
      assert_equal 1, calendar.voucher_awards.size
      award = calendar.voucher_awards.first
      assert_equal "Dinner date", award[:title]
      assert_equal "Surprise", award[:details]
      assert_equal "2024-11-30T10:00:00Z", award[:awarded_at]
      refute award[:redeemed]
    end

    test "check_in marks the day, bumps totals, and persists" do
      write_calendar(
        days: {
          (@day - 1) => { checked_in: true, stars: 1 },
          @day => { checked_in: false, stars: 0 }
        }
      )

      calendar = AdventCalendar.new(@day, data_file: @data_file)
      refute_predicate calendar, :checked_in?

      calendar.check_in

      assert_predicate calendar, :checked_in?
      assert_equal 2, calendar.total_check_ins
      assert_equal 2, calendar.total_stars
      assert_equal 0, calendar.draws_available

      reloaded = AdventCalendar.new(@day, data_file: @data_file)
      assert_predicate reloaded, :checked_in?
      assert_equal 2, reloaded.total_check_ins
      assert_equal 2, reloaded.total_stars
    end

    test "reset_check_in clears entry and updates totals" do
      write_calendar(
        days: {
          (@day - 1) => { checked_in: true, stars: 1 },
          @day => { checked_in: true, stars: 1 }
        }
      )

      calendar = AdventCalendar.new(@day, data_file: @data_file)
      assert_predicate calendar, :checked_in?

      calendar.reset_check_in

      refute_predicate calendar, :checked_in?
      assert_equal 1, calendar.total_check_ins
      assert_equal 1, calendar.total_stars
      assert_equal 0, calendar.draws_unlocked

      reloaded = AdventCalendar.new(@day, data_file: @data_file)
      refute_predicate reloaded, :checked_in?
      assert_equal 1, reloaded.total_check_ins
      assert_equal 1, reloaded.total_stars
    end

    test "attempt_puzzle awards second star when answer matches" do
      write_calendar(
        days: {
          @day => { checked_in: false, stars: 0, puzzle_answer: "hooters" }
        }
      )

      calendar = AdventCalendar.new(@day, data_file: @data_file)

      refute calendar.checked_in?
      assert_equal 0, calendar.total_stars

      assert calendar.attempt_puzzle!("hooters"), "expected puzzle attempt to succeed"
      assert_equal 1, calendar.total_stars
      refute calendar.puzzle_completed?, "puzzle should not be marked complete until check-in star is earned"

      calendar.check_in
      assert_equal 2, calendar.total_stars
      assert calendar.puzzle_completed?
    end

    test "attempt_puzzle does not add star on incorrect answer" do
      write_calendar(
        days: {
          @day => { checked_in: false, stars: 0, puzzle_answer: "hooters" }
        }
      )

      calendar = AdventCalendar.new(@day, data_file: @data_file)

      refute calendar.attempt_puzzle!("wrong")
      assert_equal 0, calendar.total_stars
      refute calendar.puzzle_completed?
    end

    test "attempt_puzzle only awards once" do
      write_calendar(
        days: {
          @day => { checked_in: true, stars: 1, puzzle_answer: "hooters" }
        }
      )

      calendar = AdventCalendar.new(@day, data_file: @data_file)
      assert_equal 1, calendar.total_stars

      assert calendar.attempt_puzzle!("hooters")
      assert_equal 2, calendar.total_stars
      assert calendar.puzzle_completed?

      assert calendar.attempt_puzzle!("hooters")
      assert_equal 2, calendar.total_stars
    end

    test "draw_voucher consumes unlocked opportunity and persists" do
      write_calendar(
        days: {
          (@day - 2) => { checked_in: true, stars: 1 },
          (@day - 1) => { checked_in: true, stars: 1 },
          @day => { checked_in: true, stars: 1 }
        }
      )

      calendar = AdventCalendar.new(@day, data_file: @data_file)
      assert_equal 3, calendar.total_stars
      assert_equal 1, calendar.draws_available

      travel_to Time.zone.parse("2024-12-01 12:00:00") do
        award = calendar.draw_voucher!(random: Random.new(42), catalog: [{ title: "massage", details: "relax" }])

        assert_equal "massage", award.title
        assert_match(/voucher-\d{4}/, award.id)
        assert_equal 0, calendar.draws_available
      end

      reloaded = AdventCalendar.new(@day, data_file: @data_file)
      assert_equal 0, reloaded.draws_available
      assert_equal 1, reloaded.draws_claimed
      assert_equal 1, reloaded.voucher_awards.size
      reloaded_award = reloaded.voucher_awards.first
      assert_equal "massage", reloaded_award[:title]
      refute reloaded_award[:redeemed]
    end

    test "draw_voucher raises error when not enough stars" do
      write_calendar(
        days: {
          @day => { checked_in: true, stars: 1 }
        }
      )

      calendar = AdventCalendar.new(@day, data_file: @data_file)

      assert_raises(Adapter::AdventCalendar::NoEligibleDrawsError) do
        calendar.draw_voucher!
      end
    end

    test "redeem_voucher marks voucher and persists" do
      write_calendar(
        days: {
          (@day - 2) => { checked_in: true, stars: 1 },
          (@day - 1) => { checked_in: true, stars: 1 },
          @day => { checked_in: true, stars: 1 }
        }
      )

      calendar = AdventCalendar.new(@day, data_file: @data_file)
      award = calendar.draw_voucher!(catalog: [{ title: "massage", details: "relax" }])

      redeemed = calendar.redeem_voucher!(award.id)
      assert redeemed.redeemed?

      reloaded = AdventCalendar.new(@day, data_file: @data_file)
      stored = reloaded.voucher_awards.first
      assert stored[:redeemed]
      assert_includes stored[:redeemed_at], "T"
    end

    test "redeem_voucher prevents duplicate redemption" do
      write_calendar(
        days: {
          (@day - 1) => { checked_in: true, stars: 1 },
          @day => { checked_in: true, stars: 1 },
          (@day + 1) => { checked_in: true, stars: 1 }
        }
      )

      calendar = AdventCalendar.new(@day, data_file: @data_file)
      award = calendar.draw_voucher!(catalog: [{ title: "cookie", details: "sweet" }])
      calendar.redeem_voucher!(award.id)

      assert_raises(Adapter::AdventCalendar::VoucherAlreadyRedeemedError) do
        calendar.redeem_voucher!(award.id)
      end
    end

    test "redeem_voucher raises when voucher missing" do
      write_calendar(days: { @day => { checked_in: true, stars: 3 } })

      calendar = AdventCalendar.new(@day, data_file: @data_file)

      assert_raises(Adapter::AdventCalendar::VoucherNotFoundError) do
        calendar.redeem_voucher!("unknown")
      end
    end

    private

    def write_calendar(days:, awards: [])
      payload = {
        "days" => build_days_payload(days),
        "voucher_awards" => awards,
        "voucher_sequence" => 1
      }

      File.write(@data_file, payload.to_yaml)
    end

    def build_days_payload(days)
      days.each_with_object({}) do |(date, attrs), memo|
        key = date.is_a?(Date) ? date.iso8601 : date.to_s
        memo[key] = sanitize_day_attributes(attrs, key)
      end
    end

    def sanitize_day_attributes(attrs, date_key)
      return default_day_payload(date_key) unless attrs.is_a?(Hash)

      answer = value_for(attrs, :puzzle_answer)

      {
        "checked_in" => truthy?(value_for(attrs, :checked_in)),
        "stars" => (value_for(attrs, :stars) || 0).to_i,
        "puzzle_answer" => answer&.to_s || default_puzzle_answer_for(date_key)
      }
    end

    def default_day_payload(date_key)
      {
        "checked_in" => false,
        "stars" => 0,
        "puzzle_answer" => default_puzzle_answer_for(date_key)
      }
    end

    def value_for(attrs, key)
      attrs[key] || attrs[key.to_s]
    end

    def truthy?(value)
      [true, "true", 1, "1"].include?(value)
    end

    def build_award(title, redeemed: false)
      {
        "id" => SecureRandom.uuid,
        "title" => title,
        "details" => "Surprise",
        "awarded_at" => "2024-11-30T10:00:00Z",
        "redeemed_at" => redeemed ? "2024-12-02T09:00:00Z" : nil
      }
    end

    def default_puzzle_answer_for(date_key)
      date_key.to_s == @day.iso8601 ? "hooters" : "ember"
    end
  end
  # rubocop:enable Metrics/ClassLength
end

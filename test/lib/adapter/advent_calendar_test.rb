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
      assert_equal 0, calendar.remaining_stars
      assert_equal 0, calendar.used_stars
    end

    test "loads checked in day with stars" do
      write_calendar(
        days: {
          @day => { checked_in: true, stars: 2 }
        },
        spent_stars: 3,
        awards: [build_award("Dinner date")]
      )

      calendar = AdventCalendar.new(@day, data_file: @data_file)

      assert_predicate calendar, :checked_in?
      assert_equal 2, calendar.total_stars
      assert_equal 1, calendar.total_check_ins
      assert_equal 3, calendar.used_stars
      assert_equal 0, calendar.remaining_stars
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
      assert_equal 2, calendar.remaining_stars

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
      assert_equal 1, calendar.remaining_stars

      reloaded = AdventCalendar.new(@day, data_file: @data_file)
      refute_predicate reloaded, :checked_in?
      assert_equal 1, reloaded.total_check_ins
      assert_equal 1, reloaded.total_stars
    end

    test "draw_voucher consumes stars and persists" do
      write_calendar(
        days: {
          (@day - 2) => { checked_in: true, stars: 1 },
          (@day - 1) => { checked_in: true, stars: 1 },
          @day => { checked_in: true, stars: 1 }
        }
      )

      calendar = AdventCalendar.new(@day, data_file: @data_file)

      travel_to Time.zone.parse("2024-12-01 12:00:00") do
        award = calendar.draw_voucher!(random: Random.new(42), catalog: [{ title: "massage", details: "relax" }])

        assert_equal "massage", award.title
        assert_match(/voucher-\d{4}/, award.id)
        assert_equal 3, calendar.used_stars
        assert_equal 0, calendar.remaining_stars
      end

      reloaded = AdventCalendar.new(@day, data_file: @data_file)
      assert_equal 3, reloaded.used_stars
      assert_equal 0, reloaded.remaining_stars
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

      assert_raises(Adapter::AdventCalendar::NotEnoughStarsError) do
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

    def write_calendar(days:, spent_stars: 0, awards: [])
      payload = {
        "days" => build_days_payload(days),
        "spent_stars" => spent_stars,
        "voucher_awards" => awards,
        "voucher_sequence" => 1
      }

      File.write(@data_file, payload.to_yaml)
    end

    def build_days_payload(days)
      days.each_with_object({}) do |(date, attrs), memo|
        key = date.is_a?(Date) ? date.iso8601 : date.to_s
        memo[key] = sanitize_day_attributes(attrs)
      end
    end

    def sanitize_day_attributes(attrs)
      return { "checked_in" => false, "stars" => 0 } unless attrs.is_a?(Hash)

      {
        "checked_in" => truthy?(value_for(attrs, :checked_in)),
        "stars" => (value_for(attrs, :stars) || 0).to_i
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
  end
  # rubocop:enable Metrics/ClassLength
end

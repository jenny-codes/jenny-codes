# typed: false
# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

module Adapter
  class AdventCalendarTest < ActiveSupport::TestCase
    def setup
      @day = Date.new(2025, 11, 4)
      travel_to Time.zone.local(2025, 11, 4, 9, 0, 0)
    end

    def teardown
      travel_back
    end

    test "defaults to unchecked day when none exists" do
      calendar = AdventCalendar.on(@day)

      refute_predicate calendar, :checked_in?
      assert_equal 0, calendar.total_stars
      assert_equal 0, calendar.total_check_ins
      assert_equal 0, calendar.draws_unlocked
      assert_equal 0, calendar.draws_available
    end

    test "loads checked in day with stars" do
      create_day(@day, stars: 35, puzzle_answer: "ember")
      create_day(@day - 1, stars: 0, puzzle_answer: "ember")
      create_award(title: "Dinner date", details: "Surprise", awarded_at: Time.zone.parse("2024-11-30 10:00"))

      calendar = AdventCalendar.on(@day)

      assert_predicate calendar, :checked_in?
      assert_equal 35, calendar.total_stars
      assert_equal 1, calendar.total_check_ins
      assert_equal 4, calendar.draws_unlocked
      assert_equal 4 - Adapter::AdventCalendar::Store.instance.all_vouchers.count, calendar.draws_available
      assert_equal 1, calendar.vouchers.size
      award = calendar.vouchers.first
      assert_equal "Dinner date", award[:title]
      assert_equal "Surprise", award[:details]
      assert_includes award[:awarded_at], "2024-11-30T10:00:00"
      refute award[:redeemed]
    end

    test "check_in marks the day, bumps totals, and persists" do
      create_day(@day - 1, stars: 1, puzzle_answer: "ember")
      create_day(@day, stars: 0, puzzle_answer: "hooters")

      calendar = AdventCalendar.on(@day)
      refute_predicate calendar, :checked_in?

      calendar.check_in

      assert_predicate calendar, :checked_in?
      assert_equal 2, calendar.total_check_ins
      assert_equal 2, calendar.total_stars
      assert_equal 0, calendar.draws_available

      reloaded = AdventCalendar.on(@day)
      assert_predicate reloaded, :checked_in?
      assert_equal 2, reloaded.total_check_ins
      assert_equal 2, reloaded.total_stars
    end

    test "reset_check_in clears entry and updates totals" do
      create_day(@day - 1, stars: 1, puzzle_answer: "ember")
      create_day(@day, stars: 1, puzzle_answer: "hooters")

      calendar = AdventCalendar.on(@day)
      assert_predicate calendar, :checked_in?

      calendar.reset_check_in

      refute_predicate calendar, :checked_in?
      assert_equal 1, calendar.total_check_ins
      assert_equal 1, calendar.total_stars
      assert_equal 0, calendar.draws_unlocked

      reloaded = AdventCalendar.on(@day)
      refute_predicate reloaded, :checked_in?
      assert_equal 1, reloaded.total_check_ins
      assert_equal 1, reloaded.total_stars
    end

    test "attempt_puzzle awards second star when answer matches" do
      create_day(@day, stars: 0, puzzle_answer: "hooters")

      calendar = AdventCalendar.on(@day)

      refute calendar.checked_in?
      assert_equal 0, calendar.total_stars

      assert calendar.attempt_puzzle!("hooters")
      assert_equal 0, calendar.total_stars
      refute calendar.puzzle_completed?

      calendar.check_in
      assert calendar.attempt_puzzle!("hooters")
      assert_equal 2, calendar.total_stars
      assert calendar.puzzle_completed?
    end

    test "attempt_puzzle does not add star on incorrect answer" do
      create_day(@day, stars: 0, puzzle_answer: "hooters")

      calendar = AdventCalendar.on(@day)

      refute calendar.attempt_puzzle!("wrong")
      assert_equal 0, calendar.total_stars
      refute calendar.puzzle_completed?
    end

    test "attempt_puzzle only awards once" do
      create_day(@day, stars: 1, puzzle_answer: "hooters")

      calendar = AdventCalendar.on(@day)
      assert_equal 1, calendar.total_stars

      assert calendar.attempt_puzzle!("hooters")
      assert_equal 2, calendar.total_stars
      assert calendar.puzzle_completed?

      assert calendar.attempt_puzzle!("hooters")
      assert_equal 2, calendar.total_stars
    end

    test "draw_voucher consumes unlocked opportunity and persists" do
      create_day(@day - 2, stars: 1, puzzle_answer: "ember")
      create_day(@day - 1, stars: 1, puzzle_answer: "ember")
      create_day(@day, stars: 1, puzzle_answer: "hooters")

      calendar = AdventCalendar.on(@day)
      assert_equal 3, calendar.total_stars
      assert_equal 1, calendar.draws_available

      travel_to Time.zone.parse("2024-12-01 12:00:00") do
        award = calendar.draw_voucher!(
          random: Random.new(42),
          catalog: [{ title: "massage", details: "relax", chance: 100 }]
        )

        assert_equal "massage", award.title
        assert_match(/voucher-\d{4}/, award.id)
        assert_equal 0, calendar.draws_available
      end

      reloaded = AdventCalendar.on(@day)
      assert_equal 0, reloaded.draws_available
      assert_equal 1, reloaded.draws_claimed
      assert_equal 1, reloaded.vouchers.size
      reloaded_award = reloaded.vouchers.first
      assert_equal "massage", reloaded_award[:title]
      refute reloaded_award[:redeemed]
    end

    test "draw_voucher raises error when not enough stars" do
      create_day(@day, stars: 1, puzzle_answer: "hooters")

      calendar = AdventCalendar.on(@day)

      assert_raises(Adapter::AdventCalendar::NoEligibleDrawsError) do
        calendar.draw_voucher!
      end
    end

    test "draw_voucher respects chance weighting for lower ticket" do
      create_day(@day - 2, stars: 1, puzzle_answer: "ember")
      create_day(@day - 1, stars: 1, puzzle_answer: "ember")
      create_day(@day, stars: 1, puzzle_answer: "hooters")

      calendar = AdventCalendar.on(@day)
      rng = Minitest::Mock.new
      rng.expect(:rand, 59, [100])

      award = calendar.draw_voucher!(
        random: rng,
        catalog: [
          { title: "Common", details: "plain", chance: 60 },
          { title: "Rare", details: "shiny", chance: 40 }
        ]
      )

      assert_equal "Common", award.title
      rng.verify
    end

    test "draw_voucher respects chance weighting for upper ticket" do
      create_day(@day - 2, stars: 1, puzzle_answer: "ember")
      create_day(@day - 1, stars: 1, puzzle_answer: "ember")
      create_day(@day, stars: 1, puzzle_answer: "hooters")

      calendar = AdventCalendar.on(@day)
      rng = Minitest::Mock.new
      rng.expect(:rand, 90, [100])

      award = calendar.draw_voucher!(
        random: rng,
        catalog: [
          { title: "Common", details: "plain", chance: 60 },
          { title: "Rare", details: "shiny", chance: 40 }
        ]
      )

      assert_equal "Rare", award.title
      rng.verify
    end

    test "draw_voucher raises when chances do not sum to 100" do
      create_day(@day - 2, stars: 1, puzzle_answer: "ember")
      create_day(@day - 1, stars: 1, puzzle_answer: "ember")
      create_day(@day, stars: 1, puzzle_answer: "hooters")

      calendar = AdventCalendar.on(@day)

      assert_raises RuntimeError do
        calendar.draw_voucher!(
          catalog: [
            { title: "Common", details: "plain", chance: 30 },
            { title: "Rare", details: "shiny", chance: 30 }
          ]
        )
      end
    end

    test "redeem_voucher marks voucher and persists" do
      create_day(@day - 2, stars: 1, puzzle_answer: "ember")
      create_day(@day - 1, stars: 1, puzzle_answer: "ember")
      create_day(@day, stars: 1, puzzle_answer: "hooters")

      calendar = AdventCalendar.on(@day)
      award = calendar.draw_voucher!(catalog: [{ title: "massage", details: "relax", chance: 100 }])

      redeemed = calendar.redeem_voucher!(award.id)
      assert redeemed.redeemed?

      reloaded = AdventCalendar.on(@day)
      stored = reloaded.vouchers.first
      assert stored[:redeemed]
      assert_includes stored[:redeemed_at], "T"
    end

    test "redeem_voucher prevents duplicate redemption" do
      create_day(@day - 1, stars: 1, puzzle_answer: "ember")
      create_day(@day, stars: 1, puzzle_answer: "hooters")
      create_day(@day + 1, stars: 1, puzzle_answer: "ember")

      calendar = AdventCalendar.on(@day)
      award = calendar.draw_voucher!(catalog: [{ title: "cookie", details: "sweet", chance: 100 }])
      calendar.redeem_voucher!(award.id)

      assert_raises(Adapter::AdventCalendar::VoucherAlreadyRedeemedError) do
        calendar.redeem_voucher!(award.id)
      end
    end

    private

    def create_day(day, stars:, puzzle_answer: nil)
      Adapter::AdventCalendar::Store.instance.write_day(
        day: day,
        stars: stars,
        puzzle_answer: puzzle_answer
      )
    end

    def create_award(title:, details:, awarded_at:, redeemed_at: nil)
      store = Adapter::AdventCalendar::Store.instance
      voucher = store.append_voucher(
        title: title,
        details: details,
        awarded_at: awarded_at.iso8601
      )
      return unless redeemed_at

      store.update_voucher(voucher["id"], redeemed_at: redeemed_at.iso8601)
    end
  end
end

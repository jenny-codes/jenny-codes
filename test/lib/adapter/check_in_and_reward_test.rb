# typed: false
# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

module Adapter
  module AdventCalendar
    class CheckInAndRewardTest < ActiveSupport::TestCase
      SAMPLE_DAY = Date.new(2025, 11, 8)

      setup do
        travel_to Time.zone.local(2025, 11, 8, 9, 0, 0)
        reset_store!
      end

      teardown do
        travel_back
      end

      test "new day starts unchecked with zero totals" do
        check_in = build_check_in
        reward = build_reward

        assert_equal CheckIn::STAGE_PART_1, check_in.current_stage
        assert_equal 0, check_in.total_stars
        assert_equal 0, check_in.total_check_ins
        assert_equal 0, reward.draws_unlocked
        assert_equal 0, reward.draws_available
      end

      test "check in marks the day and updates totals" do
        create_day(SAMPLE_DAY - 1, stars: 1, puzzle_answer: "ember")

        check_in = build_check_in
        assert_equal CheckIn::STAGE_PART_1, check_in.current_stage

        check_in.complete_part1

        assert_equal CheckIn::STAGE_PART_2, check_in.current_stage
        assert_equal 2, build_check_in.total_stars
        assert_equal 2, build_check_in.total_check_ins
      end

      test "reset check in clears the stars" do
        create_day(SAMPLE_DAY, stars: 1, puzzle_answer: "ember")

        check_in = build_check_in
        assert_equal CheckIn::STAGE_PART_2, check_in.current_stage

        check_in.reset_part1

        assert_equal CheckIn::STAGE_PART_1, build_check_in.current_stage
        assert_equal 0, build_check_in.total_stars
      end

      test "attempt puzzle requires prior check in" do
        create_day(SAMPLE_DAY, stars: 0, puzzle_answer: "ember")
        check_in = build_check_in

        assert check_in.attempt_part2!("ember")
        assert_equal CheckIn::STAGE_DONE, check_in.current_stage
        assert_equal 2, build_check_in.total_stars

        check_in.complete_part1

        assert_equal CheckIn::STAGE_PART_2, check_in.current_stage
        assert_equal 1, build_check_in.total_stars

        assert check_in.attempt_part2!("ember")
        assert_equal CheckIn::STAGE_DONE, check_in.current_stage
        assert_equal 2, build_check_in.total_stars

        assert check_in.attempt_part2!("ember"), "second attempt should be idempotent"
        assert_equal 2, build_check_in.total_stars
      end

      test "complete puzzle promotes checked day to two stars" do
        create_day(SAMPLE_DAY, stars: 1, puzzle_answer: "ember")
        check_in = build_check_in

        assert check_in.complete_part2!
        assert_equal CheckIn::STAGE_DONE, check_in.current_stage
        assert_equal 2, build_check_in.total_stars
      end

      test "wildcard puzzle answer accepts any attempt" do
        wildcard_day = SAMPLE_DAY + 1
        store.reset!(
          calendar_days: { wildcard_day.iso8601 => { "stars" => 1, "puzzle_answer" => "*" } },
          vouchers: [],
          voucher_options: store.voucher_options,
          prompts: prompt_overrides(wildcard_day => prompt_payload_for(wildcard_day, "*"))
        )

        check_in = CheckIn.new(day: wildcard_day, store: store)

        assert_equal CheckIn::STAGE_PART_2, check_in.current_stage
        assert check_in.attempt_part2!("anything at all")
        assert_equal CheckIn::STAGE_DONE, check_in.current_stage
      end

      test "blank puzzle answer accepts any attempt" do
        blank_day = SAMPLE_DAY + 2
        store.reset!(
          calendar_days: { blank_day.iso8601 => { "stars" => 1, "puzzle_answer" => "" } },
          vouchers: [],
          voucher_options: store.voucher_options,
          prompts: prompt_overrides(blank_day => prompt_payload_for(blank_day, ""))
        )

        check_in = CheckIn.new(day: blank_day, store: store)

        assert_equal CheckIn::STAGE_PART_2, check_in.current_stage
        assert check_in.attempt_part2!("any response")
        assert_equal CheckIn::STAGE_DONE, check_in.current_stage
      end

      test "draw uses unlocked opportunity and persists voucher" do
        seed_for_draw(3)
        reward = build_reward

        assert_equal 1, reward.draws_available

        travel_to Time.zone.local(2025, 11, 8, 12, 0, 0) do
          award = reward.draw!(
            random: Random.new(42),
            catalog: [{ title: "massage", details: "relax", chance: 100, redeemable_at: SAMPLE_DAY.iso8601 }]
          )

          assert_equal "massage", award.title
        end

        reloaded = build_reward
        assert_equal 0, reloaded.draws_available
        assert_equal 1, reloaded.vouchers.size
        voucher = reloaded.vouchers.first
        assert_equal "massage", voucher[:title]
        refute voucher[:redeemed]
      end

      test "draw raises when no draws available" do
        reward = build_reward

        assert_raises(Adapter::AdventCalendar::NoEligibleDrawsError) do
          reward.draw!
        end
      end

      test "draw respects weighted chances" do
        seed_for_draw(3)
        reward = build_reward
        rng = Minitest::Mock.new
        rng.expect(:rand, 75, [100])

        award = reward.draw!(
          random: rng,
          catalog: [
            { title: "Common", details: "plain", chance: 60, redeemable_at: (SAMPLE_DAY - 1).iso8601 },
            { title: "Rare", details: "shiny", chance: 40, redeemable_at: (SAMPLE_DAY + 1).iso8601 }
          ]
        )

        assert_equal "Rare", award.title
        rng.verify
      end

      test "redeem! marks voucher as redeemed" do
        seed_for_draw(3)
        reward = build_reward
        voucher = reward.draw!(catalog: [{ title: "massage", details: "relax", chance: 100,
                                           redeemable_at: SAMPLE_DAY.iso8601 }])

        redeemed = reward.redeem!(voucher.id)
        assert_match(/voucher-\d{4}/, redeemed.id)
        assert redeemed.redeemed?
        assert redeemed.redeemable?
      end

      test "redeem! defers when not yet redeemable" do
        seed_for_draw(3)
        reward = build_reward
        future_date = (SAMPLE_DAY + 3).iso8601
        voucher = reward.draw!(catalog: [{ title: "massage", details: "relax", chance: 100,
                                           redeemable_at: future_date }])

        assert_raises(Adapter::AdventCalendar::VoucherNotRedeemableError) do
          reward.redeem!(voucher.id)
        end
      end

      private

      def store
        Adapter::AdventCalendar::Store.instance
      end

      def build_check_in(day = SAMPLE_DAY)
        CheckIn.new(day: day, store: store)
      end

      def build_reward(day = SAMPLE_DAY)
        Reward.new(day: day, store: store)
      end

      def reset_store!
        store.reset!(
          calendar_days: {},
          vouchers: [],
          voucher_options: [
            {
              "title" => "Massage",
              "details" => "relax",
              "chance" => 100,
              "redeemable_at" => SAMPLE_DAY.iso8601
            }
          ],
          prompts: base_prompt_payloads
        )
      end

      def create_day(day, stars:, puzzle_answer: nil)
        store.write_day(day: day, stars: stars, puzzle_answer: puzzle_answer)
      end

      def seed_for_draw(total_days)
        (1..total_days).each do |offset|
          create_day(SAMPLE_DAY - offset, stars: 1, puzzle_answer: "ember")
        end
      end

      def prompt_payload_for(day, answer)
        {
          "part1_prompt_1" => "Greetings for #{day.iso8601}",
          "part2_prompt_1" => "Continue on #{day.iso8601}",
          "done_prompt_1" => "Done #{day.iso8601}",
          "story_1" => "Story #{day.iso8601}",
          "puzzle_format" => "text",
          "puzzle_prompt" => "What is the answer?",
          "puzzle_answer" => answer.to_s
        }
      end

      def base_prompt_payloads
        (SAMPLE_DAY - 5..SAMPLE_DAY + 5).each_with_object({}) do |day, memo|
          memo[day.iso8601] = prompt_payload_for(day, "ember")
        end
      end

      def prompt_overrides(overrides)
        base_prompt_payloads.merge(
          overrides.transform_keys(&:iso8601)
        )
      end
    end
  end
end

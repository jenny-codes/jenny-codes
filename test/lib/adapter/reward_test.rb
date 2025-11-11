# typed: false
# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

module Adapter
  module AdventCalendar
    class RewardTest < ActiveSupport::TestCase
      SAMPLE_DAY = Date.new(2025, 11, 8)

      setup do
        travel_to Time.zone.local(2025, 11, 8, 9, 0, 0)
        reset_store!
      end

      teardown do
        travel_back
      end

      test "draw uses unlocked opportunity and persists voucher" do
        seed_for_draw(3)
        reward = Reward.for(SAMPLE_DAY)

        assert_equal 1, reward.draws_available

        travel_to Time.zone.local(2025, 11, 8, 12, 0, 0) do
          award = reward.draw!(
            random: Random.new(42),
            catalog: [{ title: "massage", details: "relax", chance: 100, redeemable_at: SAMPLE_DAY.iso8601 }]
          )

          assert_equal "massage", award.title
        end

        reloaded = Reward.for(SAMPLE_DAY)
        assert_equal 0, reloaded.draws_available
        assert_equal 1, reloaded.vouchers.size
        voucher = reloaded.vouchers.first
        assert_equal "massage", voucher[:title]
        refute voucher[:redeemed]
      end

      test "draw raises when no draws available" do
        reward = Reward.for(SAMPLE_DAY)

        assert_raises(Adapter::AdventCalendar::NoEligibleDrawsError) do
          reward.draw!
        end
      end

      test "draw respects weighted chances" do
        seed_for_draw(3)
        reward = Reward.for(SAMPLE_DAY)
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
        reward = Reward.for(SAMPLE_DAY)
        voucher = reward.draw!(catalog: [{ title: "massage", details: "relax", chance: 100,
                                           redeemable_at: SAMPLE_DAY.iso8601 }])

        redeemed = reward.redeem!(voucher.id)
        assert_match(/voucher-\d{4}/, redeemed.id)
        assert redeemed.redeemed?
        assert redeemed.redeemable?
      end

      test "redeem! defers when not yet redeemable" do
        seed_for_draw(3)
        reward = Reward.for(SAMPLE_DAY)
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
          prompts: base_prompt_payloads,
          puzzle_attempts: []
        )
      end

      def create_day(day, stars: 0)
        data = store.all_days.index_by { |entry| entry["day"] }
        data[day.iso8601] = { "stars" => stars, "puzzle_answer" => "ember" }
        store.reset!(
          calendar_days: data,
          vouchers: store.all_vouchers,
          voucher_options: store.voucher_options,
          prompts: base_prompt_payloads,
          puzzle_attempts: store.puzzle_attempts
        )
      end

      def seed_for_draw(total_days)
        (1..total_days).each do |offset|
          create_day(SAMPLE_DAY - offset, stars: 1)
        end
      end

      def prompt_payload_for(day)
        {
          "part1_prompt_1" => "Greetings for #{day.iso8601}",
          "part2_prompt_1" => "Continue on #{day.iso8601}",
          "done_prompt_1" => "Done #{day.iso8601}",
          "story_1" => "Story #{day.iso8601}",
          "puzzle_format" => "text",
          "puzzle_prompt" => "What is the answer?",
          "puzzle_answer" => "ember"
        }
      end

      def base_prompt_payloads
        (SAMPLE_DAY - 5..SAMPLE_DAY + 5).each_with_object({}) do |day, memo|
          memo[day.iso8601] = prompt_payload_for(day)
        end
      end
    end
  end
end

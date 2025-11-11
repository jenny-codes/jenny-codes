# typed: false
# frozen_string_literal: true

require "test_helper"

module Adapter
  module AdventCalendar
    class CheckInTest < ActiveSupport::TestCase
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

        assert_equal CheckIn::STAGE_PART_1, check_in.current_stage
        assert_equal 0, check_in.total_stars
        assert_equal 0, check_in.total_check_ins
      end

      test "complete part one awards first star" do
        create_day(SAMPLE_DAY - 1, stars: 1, puzzle_answer: "ember")

        check_in = build_check_in
        check_in.complete_part1

        assert_equal CheckIn::STAGE_PART_2, check_in.current_stage
        assert_equal 2, build_check_in.total_stars
        assert_equal 2, build_check_in.total_check_ins
      end

      test "reset part one clears stars" do
        create_day(SAMPLE_DAY, stars: 1, puzzle_answer: "ember")

        check_in = build_check_in
        check_in.reset_part1

        assert_equal CheckIn::STAGE_PART_1, build_check_in.current_stage
        assert_equal 0, build_check_in.total_stars
      end

      test "complete part two promotes to done" do
        create_day(SAMPLE_DAY, stars: 1, puzzle_answer: "ember")
        check_in = build_check_in

        check_in.complete_part2!

        assert_equal CheckIn::STAGE_DONE, check_in.current_stage
        assert_equal 2, build_check_in.total_stars
      end

      test "record puzzle attempt appends to store" do
        check_in = build_check_in
        timestamp = Time.zone.local(2025, 11, 8, 10, 30, 0)

        travel_to timestamp do
          check_in.record_puzzle_attempt("ember")
        end

        attempts = store.puzzle_attempts
        assert_equal 1, attempts.size
        entry = attempts.first
        assert_equal SAMPLE_DAY.iso8601, entry["day"]
        assert_equal "ember", entry["attempt"]
        assert_equal timestamp.iso8601, entry["timestamp"]
      end

      private

      def store
        Adapter::AdventCalendar::Store.instance
      end

      def build_check_in(day = SAMPLE_DAY)
        CheckIn.new(day: day, store: store)
      end

      def reset_store!(calendar_days: {}, prompts: base_prompt_payloads)
        store.reset!(
          calendar_days: calendar_days,
          vouchers: [],
          voucher_options: [
            {
              "title" => "Massage",
              "details" => "relax",
              "chance" => 100,
              "redeemable_at" => SAMPLE_DAY.iso8601
            }
          ],
          prompts: prompts,
          puzzle_attempts: []
        )
      end

      def create_day(day, stars:, puzzle_answer: nil)
        data = store.all_days.index_by { |entry| entry["day"] }
        data[day.iso8601] = { "stars" => stars, "puzzle_answer" => puzzle_answer }
        reset_store!(calendar_days: data)
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
    end
  end
end

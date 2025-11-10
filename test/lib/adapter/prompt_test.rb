# typed: false
# frozen_string_literal: true

require "test_helper"

module Adapter
  module AdventCalendar
    class PromptTest < ActiveSupport::TestCase
      SAMPLE_DAY = Date.new(2025, 11, 8)

      setup do
        travel_to Time.zone.local(2025, 11, 8, 9, 0, 0)
      end

      teardown do
        travel_back
      end

      test "part two answer comparison is case insensitive" do
        prompt = build_prompt(answer: "ember")

        assert prompt.part2_solved?("EmBeR")
        refute prompt.part2_solved?("charcoal")
      end

      test "wildcard answer accepts any attempt" do
        prompt = build_prompt(answer: "*")

        assert prompt.part2_solved?("anything goes")
        assert prompt.part2_solved?("")
      end

      test "blank answer accepts any attempt" do
        prompt = build_prompt(answer: "")

        assert prompt.part2_solved?("whatever you like")
      end

      private

      def build_prompt(answer: "ember")
        Adapter::AdventCalendar::Store.instance.reset!(
          calendar_days: { SAMPLE_DAY.iso8601 => { "stars" => 1 } },
          vouchers: [],
          prompts: {
            SAMPLE_DAY.iso8601 => prompt_payload(answer)
          }
        )
        Prompt.for(SAMPLE_DAY)
      end

      def prompt_payload(answer)
        {
          "part1_prompt_1" => "Greetings",
          "part2_prompt_1" => "Continue",
          "done_prompt_1" => "Done",
          "story_1" => "Story",
          "puzzle_format" => "text",
          "puzzle_prompt" => "What is the answer?",
          "puzzle_answer" => answer.to_s
        }
      end
    end
  end
end

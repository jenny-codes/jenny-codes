# typed: false
# frozen_string_literal: true

require_relative "../../config/environment"
module TestSupport
  class ResetCalendarState
    DEFAULT_DAYS = [
      { day: Date.new(2025, 10, 31), stars: 1, puzzle_answer: "comet" },
      { day: Date.new(2025, 11, 1), stars: 1, puzzle_answer: "lantern" },
      { day: Date.new(2025, 11, 2), stars: 1, puzzle_answer: "aurora" },
      { day: Date.new(2025, 11, 3), stars: 0, puzzle_answer: "hooters" }
    ].freeze

    def self.call
      new.call
    end

    def call
      store = Adapter::AdventCalendar::Store.instance
      voucher_options = if store.is_a?(Adapter::AdventCalendar::Store::TempFileStore)
                          Adapter::AdventCalendar::Store::TempFileStore::SAMPLE_VOUCHER_OPTIONS
                        end
      prompts = entries.each_with_object({}) do |entry, memo|
        memo[entry.fetch(:day).to_s] = default_prompt_payload(entry)
      end
      calendar_days = entries.each_with_object({}) do |entry, memo|
        memo[entry.fetch(:day).to_s] = {
          "stars" => entry.fetch(:stars),
          "puzzle_answer" => entry[:puzzle_answer]
        }
      end

      return unless store.respond_to?(:reset!)

      store.reset!(calendar_days: calendar_days, vouchers: [], voucher_options: voucher_options, prompts: prompts)
    end

    private

    def entries
      today = Time.zone.today
      existing = DEFAULT_DAYS.index_by { |entry| entry[:day] }
      existing[today] ||= { day: today, stars: 0, puzzle_answer: "hooters" }
      nov8 = Date.new(Adapter::AdventCalendar::END_DATE.year, 11, 8)
      existing[nov8] ||= { day: nov8, stars: 0, puzzle_answer: "ember" }
      existing.values
    end

    def default_prompt_payload(entry)
      day = entry.fetch(:day)
      answer = entry[:puzzle_answer] || "ember"

      base = {
        "part1_prompt_1" => "Hello from #{day.strftime('%b %d')}!",
        "part2_prompt_1" => "Continue on #{day.strftime('%b %d')}!",
        "done_prompt_1" => "Great job finishing #{day.strftime('%b %d')}!",
        "story_1" => "Story for #{day.strftime('%b %d')}.",
        "puzzle_format" => "text",
        "puzzle_prompt" => "What is the answer?",
        "puzzle_answer" => answer.to_s
      }

      if day.month == 11 && day.day == 8
        base.merge!(
          "part1_prompt_1" => "Yoohoo. Come here often? 😗",
          "part1_prompt_2" => "Here is a place where adventures ventures, travels unravel, and stars startle (huh?)",
          "part1_prompt_3" => "All that is wonderful waits when you press the button 👇",
          "part2_prompt_1" => "Wah. You have gathered one star from the check-in ⭐️",
          "part2_prompt_2" => "...",
          "done_prompt_1" => "The story continues tomorrow :) One more star because you are cute 😙",
          "done_prompt_2" => "⭐️",
          "story_1" => "The story will be unveiled soon. Stay tuned!",
          "puzzle_format" => "button",
          "puzzle_prompt" => "what happens?"
        )
      end

      base
    end
  end
end

TestSupport::ResetCalendarState.call

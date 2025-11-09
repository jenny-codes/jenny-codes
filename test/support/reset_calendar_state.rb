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
      calendar_days = entries.each_with_object({}) do |entry, memo|
        memo[entry.fetch(:day).to_s] = {
          "stars" => entry.fetch(:stars),
          "puzzle_answer" => entry[:puzzle_answer]
        }
      end

      return unless store.respond_to?(:reset!)

      store.reset!(calendar_days: calendar_days, vouchers: [], voucher_options: voucher_options)
    end

    private

    def entries
      today = Time.zone.today
      existing = DEFAULT_DAYS.index_by { |entry| entry[:day] }
      existing[today] ||= { day: today, stars: 0, puzzle_answer: "hooters" }
      existing.values
    end
  end
end

TestSupport::ResetCalendarState.call

# typed: false
# frozen_string_literal: true

require_relative "../../config/environment"
require "fileutils"
require "pathname"

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
      ensure_schema!
      CalendarDay.delete_all
      Voucher.delete_all

      answers = {}

      entries.each do |entry|
        CalendarDay.create!(
          day: entry.fetch(:day),
          stars: entry.fetch(:stars)
        )

        answers[entry.fetch(:day).to_s] = entry[:puzzle_answer] if entry[:puzzle_answer]
      end

      write_puzzle_answers(answers)
      Adapter::AdventCalendar.reload_puzzle_answers!
    end

    private

    def entries
      today = Time.zone.today
      existing = DEFAULT_DAYS.index_by { |entry| entry[:day] }
      existing[today] ||= { day: today, stars: 0, puzzle_answer: "hooters" }
      existing.values
    end

    def write_puzzle_answers(mapping)
      path = Pathname.new(ENV.fetch("ADVENT_PUZZLE_ANSWERS_PATH", Adapter::AdventCalendar::PUZZLE_ANSWERS_FILE.to_s))
      FileUtils.mkdir_p(path.dirname)
      payload = mapping.compact.transform_values(&:to_s)
      path.write(payload.to_yaml)
    end

    def ensure_schema!
      ActiveRecord::Tasks::DatabaseTasks.migrate
    rescue ActiveRecord::NoDatabaseError
      ActiveRecord::Tasks::DatabaseTasks.create_current
      ActiveRecord::Tasks::DatabaseTasks.migrate
    end
  end
end

TestSupport::ResetCalendarState.call

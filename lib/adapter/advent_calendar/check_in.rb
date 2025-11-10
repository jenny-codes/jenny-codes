# typed: true
# frozen_string_literal: true

require "date"
module Adapter
  module AdventCalendar
    class CheckIn
      END_DATE = Date.parse("2025-12-25")
      STAGE_PART_1 = :part1
      STAGE_PART_2 = :part2
      STAGE_DONE = :done

      DayEntry = Data.define(:stars) do
        def stars_amount
          [stars.to_i, 0].max
        end

        def part1_completed?
          stars_amount.positive?
        end

        def part2_completed?
          stars_amount >= 2
        end
      end

      attr_reader :day

      def self.for(day)
        new(day: day, store: Store.instance)
      end

      def initialize(day:, store:)
        @day = day.to_date
        @store = store
        ensure_day_entry!
      end

      def complete_part1
        write_day(stars: 1)
      end

      def reset_part1
        write_day(stars: 0)
      end

      def days_left
        (END_DATE - day).to_i
      end

      def current_stage
        return STAGE_DONE if day_entry.part2_completed?
        return STAGE_PART_2 if day_entry.part1_completed?

        STAGE_PART_1
      end

      def complete_part2!
        write_day(stars: 2)
      end

      def total_stars
        all_days.sum { |record| record["stars"].to_i }
      end

      def total_check_ins
        all_days.count { |record| record["stars"].to_i.positive? }
      end

      private

      attr_reader :store

      def day_entry
        data = store.fetch_day(day)
        DayEntry.new(data["stars"])
      end

      def ensure_day_entry!
        return if store.fetch_day(day)

        write_day(stars: 0)
      end

      def write_day(stars:)
        store.write_day(day: day, stars: stars)
      end

      def all_days
        store.all_days
      end
    end
  end
end

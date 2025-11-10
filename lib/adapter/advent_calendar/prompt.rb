# typed: true
# frozen_string_literal: true

module Adapter
  module AdventCalendar
    class Prompt
      attr_reader :day

      def self.for(day, store: Store.instance)
        new(day: day, store: store)
      end

      def initialize(day:, store: Store.instance)
        @day = day.to_date
        @store = store
        @data = store.prompt_for(@day)
        raise KeyError, "Missing advent prompt for #{@day}" unless @data
      end

      def part1_prompts
        lines_for("part1")
      end

      def part2_prompts
        lines_for("part2")
      end

      def done_prompts
        lines_for("done")
      end

      def story_lines
        lines_for("story")
      end

      def puzzle_format
        value = fetch_string("puzzle_format").presence || "text"
        value.to_s.strip.downcase.to_sym
      end

      def puzzle_prompt
        fetch_string("puzzle_prompt")
      end

      def puzzle_answer
        fetch_string("puzzle_answer")
      end

      def matches_part2_answer?(attempt)
        answer = puzzle_answer
        return true if answer == "*" || answer.blank?

        attempt.to_s.strip.casecmp?(answer.strip)
      end

      private

      attr_reader :store, :data

      def fetch_string(key)
        data.fetch(key, "").to_s.strip
      end

      def lines_for(prefix)
        prefixed_lines(prefix).presence || block_lines(prefix)
      end

      def prefixed_lines(prefix)
        keys = data.keys.select { |key| key.start_with?("#{prefix}_") }
        return [] if keys.empty?

        keys.sort_by { |key| index_for(key, prefix) }
            .map { |key| fetch_string(key) }
            .reject(&:blank?)
      end

      def block_lines(prefix)
        raw = fetch_string(prefix)
        return [] if raw.blank?

        raw.split(/\r?\n/).map(&:strip).reject(&:blank?)
      end

      def index_for(key, prefix)
        suffix = key.delete_prefix("#{prefix}_")
        match = suffix[/\d+/]
        match ? match.to_i : 0
      end
    end
  end
end

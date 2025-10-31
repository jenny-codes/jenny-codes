# typed: true
# frozen_string_literal: true

require "yaml"
require "date"

module Adapter
  class AdventCalendar
    END_DATE = Date.parse("2025-12-25")
    DATA_FILE =
      if Rails.env.test?
        Rails.root.join("test", "data", "test_advent_calendar.yml")
      else
        Rails.root.join("lib", "data", "advent_calendar.yml")
      end

    DayEntry = Data.define(:checked_in, :stars) do
      def serialize
        to_h.stringify_keys
      end
    end

    attr_reader :total_stars, :total_check_ins

    def self.on(day)
      new(day)
    end

    def initialize(day, data_file: DATA_FILE)
      @day = day.to_date
      @data_file = data_file
      @calendar_data = load_data(@data_file)
      @total_check_ins = @calendar_data.values.count(&:checked_in)
      @total_stars = @calendar_data.values.sum(&:stars)
    end

    def check_in
      return if checked_in?

      @total_check_ins += 1
      @total_stars += 1
      @calendar_data[@day] = DayEntry.new(true, 1)
      persist_data!
    end

    # This is for development purpose
    def reset_check_in
      return unless checked_in?

      @total_check_ins -= 1
      @total_stars -= day_entry.stars
      @calendar_data[@day] = DayEntry.new(false, 0)
      persist_data!
    end

    def days_left
      (END_DATE - @day).to_i
    end

    def checked_in?
      !!day_entry.checked_in
    end

    def prompt
      checked_in? ? "Wah. You are absolutely right" : "Time to check in"
    end

    def template
      checked_in? ? :after : :before
    end

    private

    def day_entry
      @calendar_data.fetch(@day)
    end

    def persist_data!
      ordered_payload = @calendar_data
                        .sort_by(&:first)
                        .to_h
                        .transform_values(&:serialize)

      File.write(@data_file, YAML.dump(ordered_payload))
    end

    def load_data(file)
      raise Errno::ENOENT unless File.exist?(file)

      raw = YAML.safe_load(File.read(file), permitted_classes: [Date], symbolize_names: true)
      raise "Malformed yml file" unless raw.is_a?(Hash)

      entries = build_calendar(raw)
      entries[@day] ||= DayEntry.new(false, 0)
      entries
    end

    def build_calendar(raw)
      raw.each_with_object({}) do |(date, attrs), memo|
        memo[coerce_date_key(date)] = DayEntry.new(**attrs)
      end
    end

    def coerce_date_key(key)
      return key if key.is_a?(Date)

      Date.iso8601(key.to_s)
    end
  end
end

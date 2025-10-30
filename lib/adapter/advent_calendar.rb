# typed: true
# frozen_string_literal: true

require "yaml"

module Adapter
  class AdventCalendar
    END_DATE = Date.parse("2025-12-25")
    DATA_FILE =
      if Rails.env.test?
        Rails.root.join("test", "data", "test_advent_calendar.yml")
      else
        Rails.root.join("lib", "data", "advent_calendar.yml")
      end

    # : Date -> self
    def self.on(day)
      new(day)
    end

    def initialize(day, data_file: DATA_FILE)
      @day = day
      @data_file = data_file
      @checked_in = load_checked_in
    end

    def check_in
      @checked_in = true
      persist_checked_in
    end

    # This is for development purpose
    def reset_check_in
      @checked_in = false
      persist_checked_in
    end

    def total_stars
      3
    end

    # : -> Integer
    def days_left
      (END_DATE - @day).to_i
    end

    # : -> Bool
    def checked_in?
      @checked_in
    end

    def prompt
      if checked_in?
        "Wah. You are absolutely right"
      else
        "Time to check in"
      end
    end

    def template
      if checked_in?
        :after
      else
        :before
      end
    end

    def seconds_until_midnight
      now = Time.zone.now
      midnight_tomorrow = now.tomorrow.beginning_of_day
      [(midnight_tomorrow - now).to_i, 0].max
    end

    private

    def load_checked_in
      data = YAML.safe_load(File.read(@data_file))
      data.is_a?(Hash) && data.key?("checked_in") ? data["checked_in"] : false
    end

    def persist_checked_in
      File.write(@data_file, { "checked_in" => @checked_in }.to_yaml)
    end
  end
end

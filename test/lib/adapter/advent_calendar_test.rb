# typed: false
# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"
require "pathname"

module Adapter
  class AdventCalendarTest < ActiveSupport::TestCase
    setup do
      @tmpdir = Dir.mktmpdir
      @data_file = Pathname.new(File.join(@tmpdir, "advent_calendar.yml"))
      @day = Date.new(2024, 12, 1)
    end

    teardown do
      FileUtils.remove_entry(@tmpdir) if @tmpdir
    end

    test "raises when data file is missing" do
      assert_raises Errno::ENOENT do
        AdventCalendar.new(@day, data_file: @data_file)
      end
    end

    test "defaults to unchecked day when file empty" do
      write_data({})

      calendar = AdventCalendar.new(@day, data_file: @data_file)

      refute_predicate calendar, :checked_in?
      assert_equal 0, calendar.total_stars
      assert_equal 0, calendar.total_check_ins
    end

    test "loads checked in day with stars" do
      write_data(
        @day.iso8601 => { "checked_in" => true, "stars" => 2 }
      )

      calendar = AdventCalendar.new(@day, data_file: @data_file)

      assert_predicate calendar, :checked_in?
      assert_equal 2, calendar.total_stars
      assert_equal 1, calendar.total_check_ins
      assert_equal :after, calendar.template
      assert_equal "Wah. You are absolutely right", calendar.prompt
    end

    test "check_in marks the day, bumps totals, and persists" do
      write_data(
        (@day - 1).iso8601 => { "checked_in" => true, "stars" => 1 },
        @day.iso8601 => { "checked_in" => false, "stars" => 0 }
      )

      calendar = AdventCalendar.new(@day, data_file: @data_file)
      refute_predicate calendar, :checked_in?

      calendar.check_in

      assert_predicate calendar, :checked_in?
      assert_equal 2, calendar.total_check_ins
      assert_equal 2, calendar.total_stars

      reloaded = AdventCalendar.new(@day, data_file: @data_file)
      assert_predicate reloaded, :checked_in?
      assert_equal 2, reloaded.total_check_ins
      assert_equal 2, reloaded.total_stars
    end

    test "reset_check_in clears entry and updates totals" do
      write_data(
        (@day - 1).iso8601 => { "checked_in" => true, "stars" => 1 },
        @day.iso8601 => { "checked_in" => true, "stars" => 2 }
      )

      calendar = AdventCalendar.new(@day, data_file: @data_file)
      assert_predicate calendar, :checked_in?

      calendar.reset_check_in

      refute_predicate calendar, :checked_in?
      assert_equal 1, calendar.total_check_ins
      assert_equal 1, calendar.total_stars

      reloaded = AdventCalendar.new(@day, data_file: @data_file)
      refute_predicate reloaded, :checked_in?
      assert_equal 1, reloaded.total_check_ins
      assert_equal 1, reloaded.total_stars
    end

    private

    def write_data(entries)
      File.write(@data_file, entries.to_yaml)
    end
  end
end

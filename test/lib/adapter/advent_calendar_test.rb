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

    test "checked_in? defaults to false when checked_in key is absent" do
      File.write(@data_file, {}.to_yaml)

      calendar = AdventCalendar.new(@day, data_file: @data_file)

      refute_predicate calendar, :checked_in?
      assert_equal "Time to check in", calendar.prompt
      assert_equal :before, calendar.template
    end

    test "checked_in? loads true from YAML" do
      File.write(@data_file, { "checked_in" => true }.to_yaml)

      calendar = AdventCalendar.new(@day, data_file: @data_file)

      assert_predicate calendar, :checked_in?
      assert_equal "Wah. You are absolutely right", calendar.prompt
      assert_equal :after, calendar.template
    end

    test "check_in updates state and persists to YAML" do
      File.write(@data_file, { "checked_in" => false }.to_yaml)

      calendar = AdventCalendar.new(@day, data_file: @data_file)
      refute_predicate calendar, :checked_in?

      calendar.check_in

      assert_predicate calendar, :checked_in?

      data = YAML.safe_load(File.read(@data_file))
      assert data["checked_in"]
    end
  end
end

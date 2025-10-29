# typed: false
# frozen_string_literal: true

require "test_helper"
require "yaml"

class AdventControllerTest < ActionDispatch::IntegrationTest
  setup { write_calendar_data }
  teardown { reset_calendar_data }

  test "index should get index view when not checked in" do
    get advent_url
    assert_response :success
  end

  test "index should get checked in view after checking in" do
    post advent_check_in_url
    get advent_url
    assert_response :success
  end

  test "after view shows reset button when checked in" do
    post advent_check_in_url
    get advent_url

    assert_select "form[action='#{advent_reset_check_in_path}'][method='post']" do
      assert_select "button", text: /reset check-in/i
    end
  end

  test "reset check in returns calendar to before state" do
    post advent_check_in_url
    post advent_reset_check_in_url

    get advent_url

    assert_select "form[action='#{advent_check_in_path}']" do
      assert_select "button", text: /check in/i
    end
  end

  private

  def write_calendar_data
    File.write(Adapter::AdventCalendar::DATA_FILE, { "checked_in" => false }.to_yaml)
  end

  def reset_calendar_data
    File.write(Adapter::AdventCalendar::DATA_FILE, {}.to_yaml)
  end
end

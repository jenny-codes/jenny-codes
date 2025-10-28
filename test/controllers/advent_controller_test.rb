# typed: false
# frozen_string_literal: true

require 'test_helper'
require 'yaml'

class AdventControllerTest < ActionDispatch::IntegrationTest
  setup { write_calendar_data }
  teardown { reset_calendar_data }

  test 'index should get index view when not checked in' do
    get advent_url
    assert_response :success
  end

  test 'index should get checked in view after checking in' do
    post advent_check_in_url
    get advent_url
    assert_response :success
  end

  private

  def write_calendar_data
    File.write(Adapter::AdventCalendar::DATA_FILE, { 'checked_in' => false }.to_yaml)
  end

  def reset_calendar_data
    File.write(Adapter::AdventCalendar::DATA_FILE, {}.to_yaml)
  end
end

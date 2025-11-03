# typed: false
# frozen_string_literal: true

require "test_helper"
require "yaml"

class AdventControllerTest < ActionDispatch::IntegrationTest
  setup { write_calendar_data }
  teardown { write_calendar_data }

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

  test "draw voucher spends stars and shows award" do
    post advent_draw_voucher_url
    assert_redirected_to advent_path(tab: "wah")
    follow_redirect!
    assert_response :success

    assert_select ".advent-voucher-card__prize"
    assert_select "form[action='#{advent_redeem_voucher_path}']", minimum: 1
    assert_select ".advent-voucher-stats", text: /Stars spent so far: 3/
  end

  test "draw voucher requires enough stars" do
    write_calendar_data(spent_stars: 3)

    post advent_draw_voucher_url
    assert_redirected_to advent_path(tab: "wah")
    follow_redirect!

    assert_select ".advent-voucher-alert", text: /Not enough stars/i
  end

  test "redeem voucher marks voucher as redeemed" do
    post advent_draw_voucher_url
    voucher_id = current_calendar.voucher_awards.first[:id]

    post advent_redeem_voucher_url, params: { voucher_id: voucher_id }
    assert_redirected_to advent_path(tab: "wah")
    follow_redirect!

    assert_select ".advent-voucher-card__status", text: /Redeemed/i
  end

  private

  def write_calendar_data(spent_stars: 0, awards: [])
    today = Time.zone.today
    days = {
      (today - 3).iso8601 => { "checked_in" => true, "stars" => 1 },
      (today - 2).iso8601 => { "checked_in" => true, "stars" => 1 },
      (today - 1).iso8601 => { "checked_in" => true, "stars" => 1 },
      today.iso8601 => { "checked_in" => false, "stars" => 0 }
    }

    payload = {
      "days" => days,
      "spent_stars" => spent_stars,
      "voucher_awards" => awards,
      "voucher_sequence" => 1
    }

    File.write(Adapter::AdventCalendar::DATA_FILE, payload.to_yaml)
  end

  def current_calendar
    Adapter::AdventCalendar.on(Time.zone.today)
  end
end

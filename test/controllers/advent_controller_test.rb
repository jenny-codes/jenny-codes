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

  test "draw voucher uses unlocked draw and shows award" do
    post advent_draw_voucher_url
    assert_redirected_to advent_path(tab: "wah")
    follow_redirect!
    assert_response :success

    assert_select ".advent-voucher-card__prize"
    assert_select "form[action='#{advent_redeem_voucher_path}']", minimum: 1
    assert_select ".advent-faq__response", text: /Draws unlocked/i
  end

  test "draw voucher requires enough stars" do
    write_calendar_data(days: insufficient_days)

    post advent_draw_voucher_url
    assert_redirected_to advent_path(tab: "wah")
    follow_redirect!

    assert_select ".advent-voucher-alert", text: /Next draw unlocks at/i
  end

  test "redeem voucher marks voucher as redeemed" do
    post advent_draw_voucher_url
    voucher_id = current_calendar.voucher_awards.first[:id]

    post advent_redeem_voucher_url, params: { voucher_id: voucher_id }
    assert_redirected_to advent_path(tab: "wah")
    follow_redirect!

    assert_select ".advent-voucher-card__status", text: /Redeemed/i
  end

  test "after view reveals done message when secret code matches" do
    post advent_check_in_url

    post advent_reveal_secret_url, params: { secret_code: "hooters" }
    assert_redirected_to advent_path(tab: "main")

    follow_redirect!
    assert_select "form[action='#{advent_reveal_secret_path}']", false
    assert_select ".advent-done-message", text: /you are rewarded one more star/i
    assert_select ".advent-secret-alert", false
    assert_select "p", text: /Part 2:/, count: 0
  end

  test "after view keeps puzzle when secret code does not match" do
    post advent_check_in_url

    post advent_reveal_secret_url, params: { secret_code: "wrong" }
    assert_redirected_to advent_path(tab: "main")

    follow_redirect!
    assert_select "form[action='#{advent_reveal_secret_path}'][method='post'] input[name='secret_code'][value='wrong']"
    assert_select ".advent-done-message", false
    assert_select ".advent-secret-alert", text: /That is not correct. Try again\?/i
    assert_select "p", text: /Part 2:/, count: 1
  end

  private

  def write_calendar_data(days: default_days, awards: [])
    payload = {
      "days" => days,
      "voucher_awards" => awards,
      "voucher_sequence" => 1
    }

    File.write(Adapter::AdventCalendar::DATA_FILE, payload.to_yaml)
  end

  def default_days
    today = Time.zone.today
    {
      (today - 3).iso8601 => { "checked_in" => true, "stars" => 1 },
      (today - 2).iso8601 => { "checked_in" => true, "stars" => 1 },
      (today - 1).iso8601 => { "checked_in" => true, "stars" => 1 },
      today.iso8601 => { "checked_in" => false, "stars" => 0 }
    }
  end

  def insufficient_days
    today = Time.zone.today
    {
      (today - 1).iso8601 => { "checked_in" => true, "stars" => 1 },
      today.iso8601 => { "checked_in" => false, "stars" => 0 }
    }
  end

  def current_calendar
    Adapter::AdventCalendar.on(Time.zone.today)
  end
end

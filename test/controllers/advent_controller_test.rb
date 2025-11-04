# typed: false
# frozen_string_literal: true

require "test_helper"
require "yaml"
require "action_mailer"

# rubocop:disable Metrics/ClassLength
class AdventControllerTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailer::Base.deliveries.clear
    write_calendar_data
  end
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

  test "check in sends notification email" do
    assert_emails 1 do
      post advent_check_in_url
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal "[Advent Calendar] Checked in for #{Time.zone.today.iso8601}", email.subject
    assert_includes email.body.to_s, Time.zone.today.iso8601
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
    assert_select ".advent-section__text", text: /draw/i
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

    assert_select ".advent-voucher-alert", text: /not redeemable/i
  end

  test "after view reveals done message when puzzle answer matches" do
    baseline_stars = current_calendar.total_stars
    post advent_check_in_url

    post advent_solve_puzzle_url, params: { puzzle_answer: "hooters" }
    assert_redirected_to advent_path(tab: "main")

    assert_equal baseline_stars + 2, current_calendar.total_stars

    follow_redirect!
    assert_select "form[action='#{advent_solve_puzzle_path}']", false
    assert_select ".advent-done-message", text: /you just got one more star/i
    assert_select ".advent-puzzle-alert", false
    assert_select "p", text: /Part 2:/, count: 0
  end

  test "after view keeps puzzle when puzzle answer does not match" do
    baseline_stars = current_calendar.total_stars
    post advent_check_in_url

    post advent_solve_puzzle_url, params: { puzzle_answer: "wrong" }
    assert_redirected_to advent_path(tab: "main")

    assert_equal baseline_stars + 1, current_calendar.total_stars

    follow_redirect!
    assert_select "form[action='#{advent_solve_puzzle_path}'][method='post'] input[name='puzzle_answer'][value='wrong']"
    assert_select ".advent-done-message", false
    assert_select ".advent-puzzle-alert", text: /That is not correct. Try again\?/i
    assert_select "p", text: /Part 2:/, count: 1
  end

  test "puzzle attempt emails include attempt" do
    post advent_check_in_url
    ActionMailer::Base.deliveries.clear

    assert_emails 1 do
      post advent_solve_puzzle_url, params: { puzzle_answer: "wrong" }
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal "[Advent Calendar] Puzzle attempt made for #{Time.zone.today.iso8601}", email.subject
    assert_includes email.body.to_s, "wrong"
    assert_includes email.body.to_s, "Incorrect"
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
      (today - 3).iso8601 => { "checked_in" => true, "stars" => 1, "puzzle_answer" => "ember" },
      (today - 2).iso8601 => { "checked_in" => true, "stars" => 1, "puzzle_answer" => "ember" },
      (today - 1).iso8601 => { "checked_in" => true, "stars" => 1, "puzzle_answer" => "ember" },
      today.iso8601 => { "checked_in" => false, "stars" => 0, "puzzle_answer" => "hooters" }
    }
  end

  def insufficient_days
    today = Time.zone.today
    {
      (today - 1).iso8601 => { "checked_in" => true, "stars" => 1, "puzzle_answer" => "ember" },
      today.iso8601 => { "checked_in" => false, "stars" => 0, "puzzle_answer" => "hooters" }
    }
  end

  def current_calendar
    Adapter::AdventCalendar.on(Time.zone.today)
  end
end
# rubocop:enable Metrics/ClassLength

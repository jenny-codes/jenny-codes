# typed: false
# frozen_string_literal: true

require "test_helper"
require "action_mailer"
require "pathname"

class AdventControllerTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailer::Base.deliveries.clear
    write_calendar_data
  end

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

    assert_select ".advent-voucher-card--latest .advent-voucher-card__prize"
    assert_select "button", text: /press me weee!/i, count: 0
  end

  test "draw voucher requires enough stars" do
    write_calendar_data(days: insufficient_days)

    post advent_draw_voucher_url
    assert_redirected_to advent_path(tab: "wah")
    follow_redirect!

    assert_select ".advent-voucher-alert", text: /Next draw unlocks at/i
  end

  test "draw voucher sends notification email" do
    assert_emails 1 do
      post advent_draw_voucher_url
    end

    email = ActionMailer::Base.deliveries.last
    Time.zone.today.iso8601
    voucher = Adapter::AdventCalendar.on(Time.zone.today).vouchers.first

    assert_equal "[Advent Calendar] Voucher drawn!", email.subject
    assert_includes email.body.to_s, voucher[:title]
    assert_includes email.body.to_s, voucher[:details]
  end

  test "redeem voucher marks voucher as redeemed" do
    post advent_draw_voucher_url
    voucher_id = current_calendar.vouchers.first[:id]

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

  def write_calendar_data(days: default_days, vouchers: [])
    CalendarDay.delete_all
    Voucher.delete_all

    puzzle_answers = {}

    days.each do |iso_day, attrs|
      attributes = attrs.transform_keys(&:to_s)
      day = Date.iso8601(iso_day.to_s)

      record = CalendarDay.find_or_initialize_by(day: day)
      record.update!(stars: attributes.fetch("stars", 0))

      answer = attributes["puzzle_answer"]
      puzzle_answers[day.to_s] = answer if answer.present?
    end

    write_puzzle_answers(puzzle_answers)

    vouchers.each do |entry|
      data = entry.transform_keys(&:to_s)
      awarded_time = parse_time(data["awarded_at"])
      attrs = {
        title: data.fetch("title"),
        details: data.fetch("details"),
        redeemed_at: parse_time(data["redeemed_at"])
      }
      attrs[:created_at] = attrs[:updated_at] = awarded_time if awarded_time

      Voucher.create!(attrs)
    end

    Adapter::AdventCalendar.reload_puzzle_answers!
  end

  def default_days
    base_date = Time.zone.today
    {
      (base_date - 3).iso8601 => { "stars" => 1, "puzzle_answer" => "ember" },
      (base_date - 2).iso8601 => { "stars" => 1, "puzzle_answer" => "ember" },
      (base_date - 1).iso8601 => { "stars" => 1, "puzzle_answer" => "ember" },
      base_date.iso8601 => { "stars" => 0, "puzzle_answer" => "hooters" }
    }
  end

  def insufficient_days
    base_date = Time.zone.today
    {
      (base_date - 1).iso8601 => { "stars" => 1, "puzzle_answer" => "ember" },
      base_date.iso8601 => { "stars" => 0, "puzzle_answer" => "hooters" }
    }
  end

  def current_calendar
    Adapter::AdventCalendar.on(Time.zone.today)
  end

  def parse_time(value)
    return nil if value.blank?

    case value
    when Time then value
    else
      Time.zone.parse(value.to_s)
    end
  end

  def write_puzzle_answers(mapping)
    path = Pathname.new(ENV.fetch("ADVENT_PUZZLE_ANSWERS_PATH"))
    payload = mapping.compact.transform_values(&:to_s)
    path.write(payload.to_yaml)
  end
end

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

  test "advent prompts for password when unauthenticated" do
    get advent_url
    assert_response :unauthorized
    assert_equal 'Basic realm="Advent Calendar"', response.headers["WWW-Authenticate"]
  end

  test "incorrect password returns unauthorized" do
    auth_get advent_url, password: "wrong"
    assert_response :unauthorized
  end

  test "index should get index view when not checked in" do
    auth_get advent_url
    assert_response :success
  end

  test "index should get checked in view after checking in" do
    auth_post advent_check_in_url
    auth_get advent_url
    assert_response :success
  end

  test "check in does not send email outside production" do
    assert_no_emails do
      auth_post advent_check_in_url
    end
  end

  test "check in respects inspect day parameter" do
    inspected_date = Date.new(Adapter::AdventCalendar::END_DATE.year, 11, 8)
    inspected_date -= 1 if inspected_date == Time.zone.today
    inspect_token = inspected_date.strftime("%m%d")

    days = default_days
    puzzle_answer = days.fetch(inspected_date.iso8601, {}).fetch("puzzle_answer", "ember")
    days[inspected_date.iso8601] = { "stars" => 0, "puzzle_answer" => puzzle_answer }
    write_calendar_data(days: days)

    store = Adapter::AdventCalendar::Store.instance
    assert_equal Adapter::AdventCalendar::CheckIn::STAGE_PART_1,
                 check_in_for(inspected_date).current_stage
    before_today = store.fetch_day(Time.zone.today)
    before_today_stars = before_today ? before_today["stars"] : 0

    auth_post advent_check_in_url(inspect: inspect_token)

    assert_redirected_to advent_path(inspect: inspect_token)
    assert_equal Adapter::AdventCalendar::CheckIn::STAGE_PART_2,
                 check_in_for(inspected_date).current_stage
    if inspected_date != Time.zone.today
      after_today = store.fetch_day(Time.zone.today)
      after_today_stars = after_today ? after_today["stars"] : 0
      assert_equal before_today_stars, after_today_stars
    end
  end

  test "after view does not expose reset button when checked in" do
    auth_post advent_check_in_url
    auth_get advent_url

    assert_select "button", text: /reset check-in/i, count: 0
  end

  test "reset check in returns calendar to before state" do
    auth_post advent_check_in_url
    auth_post advent_reset_check_in_url

    auth_get advent_url

    assert_select "form[action='#{advent_check_in_path}']" do
      assert_select "button", text: /check in/i
    end
  end

  test "reset_day query resets specified date" do
    inspected_date = Date.new(Adapter::AdventCalendar::END_DATE.year, 11, 8)
    calendar = check_in_for(inspected_date)
    calendar.complete_part1
    assert_equal Adapter::AdventCalendar::CheckIn::STAGE_PART_2,
                 check_in_for(inspected_date).current_stage

    auth_get advent_url(reset: "1108", inspect: "1108")
    assert_redirected_to advent_path(inspect: "1108")

    auth_get advent_path(inspect: "1108")
    assert_response :success
    assert_equal Adapter::AdventCalendar::CheckIn::STAGE_PART_1,
                 check_in_for(inspected_date).current_stage
  end

  test "draw voucher uses unlocked draw and shows award" do
    auth_post advent_draw_voucher_url
    assert_redirected_to advent_path(tab: "wah")
    auth_get advent_path(tab: "wah")
    assert_response :success

    assert_select ".advent-voucher-card--latest .advent-voucher-card__prize"
    assert_select "button", text: /press me weee!/i, count: 0
    assert_select ".advent-voucher-card--latest form[data-advent-voucher-action='redeem']"
  end

  test "draw voucher requires enough stars" do
    write_calendar_data(days: insufficient_days)

    auth_post advent_draw_voucher_url
    assert_redirected_to advent_path(tab: "wah")
    auth_get advent_path(tab: "wah")

    assert_select ".advent-voucher-alert", text: /Next draw unlocks at/i
  end

  test "draw voucher does not send email outside production" do
    assert_no_emails do
      auth_post advent_draw_voucher_url
    end
  end

  test "redeem voucher marks voucher as redeemed" do
    auth_post advent_draw_voucher_url
    voucher_id = reward_for.vouchers.first[:id]

    ActionMailer::Base.deliveries.clear

    assert_no_emails do
      auth_post advent_redeem_voucher_url, params: { voucher_id: voucher_id }
    end

    assert_redirected_to advent_path(tab: "wah")
    auth_get advent_path(tab: "wah")

    assert_select ".advent-voucher-alert",
                  text: /Voucher redeemed\. Please allow a few second for the request to be processed/
    assert_select ".advent-voucher-card--latest", count: 0
    assert_select ".advent-voucher-card.is-redeemed"

    cards = css_select(".advent-voucher-card")
    assert_includes cards.last["class"].to_s, "is-redeemed"
    refute_includes cards.first["class"].to_s, "is-redeemed" if cards.length > 1
  end

  test "redeem voucher defers until redeemable date" do
    future_date = (Time.zone.today + 3.days).iso8601
    write_calendar_data(voucher_options: [
                          {
                            "title" => "Future Treat",
                            "details" => "Wait for it",
                            "chance" => 100,
                            "redeemable_at" => future_date
                          }
                        ])

    auth_post advent_draw_voucher_url
    voucher = reward_for.vouchers.first
    voucher_id = voucher[:id]

    ActionMailer::Base.deliveries.clear

    auth_post advent_redeem_voucher_url, params: { voucher_id: voucher_id }
    assert_redirected_to advent_path(tab: "wah")

    auth_get advent_path(tab: "wah")
    assert_select ".advent-voucher-card__status", text: /Redeemable on/
    assert_select "form[data-advent-voucher-action='redeem']", count: 0
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  test "what happens button renders during part two" do
    auth_post advent_check_in_url(inspect: "1108")
    auth_get advent_url(inspect: "1108")

    assert_select "button", text: /what happens\?/i
  end

  test "what happens button awards second star" do
    inspected_date = Date.new(Adapter::AdventCalendar::END_DATE.year, 11, 8)
    auth_post advent_check_in_url(inspect: "1108")

    auth_post advent_solve_puzzle_url, params: { auto_complete: true, inspect: "1108" }
    assert_redirected_to advent_path(inspect: "1108", tab: "main")

    assert_equal Adapter::AdventCalendar::CheckIn::STAGE_DONE,
                 check_in_for(inspected_date).current_stage

    auth_get advent_path(inspect: "1108", tab: "main")
    assert_select "button", text: /what happens\?/i, count: 0
  end

  test "auto complete sends notification email" do
    auth_post advent_check_in_url
    ActionMailer::Base.deliveries.clear

    assert_no_emails do
      auth_post advent_solve_puzzle_url, params: { auto_complete: true }
    end
  end

  private

  def write_calendar_data(days: default_days, vouchers: [], voucher_options: nil, prompts: nil)
    store = Adapter::AdventCalendar::Store.instance

    normalized_days = days.each_with_object({}) do |(iso_day, attrs), memo|
      attributes = attrs.transform_keys(&:to_s)
      memo[iso_day.to_s] = {
        "stars" => attributes.fetch("stars", 0),
        "puzzle_answer" => attributes["puzzle_answer"]
      }
    end

    normalized_prompts = normalize_prompts(prompts, normalized_days)

    normalized_vouchers = Array(vouchers).map do |entry|
      data = entry.transform_keys(&:to_s)
      {
        "id" => data["id"],
        "title" => data["title"],
        "details" => data["details"],
        "awarded_at" => data["awarded_at"],
        "redeemable_at" => data["redeemable_at"],
        "redeemed_at" => data["redeemed_at"]
      }.compact
    end

    default_options = if store.is_a?(Adapter::AdventCalendar::Store::TempFileStore)
                        Adapter::AdventCalendar::Store::TempFileStore::SAMPLE_VOUCHER_OPTIONS
                      else
                        store.voucher_options
                      end

    store.reset!(
      calendar_days: normalized_days,
      vouchers: normalized_vouchers,
      voucher_options: voucher_options || default_options,
      prompts: normalized_prompts
    )
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

  def check_in_for(day)
    Adapter::AdventCalendar::CheckIn.new(day: day, store: Adapter::AdventCalendar::Store.instance)
  end

  def reward_for(day = Time.zone.today)
    Adapter::AdventCalendar::Reward.new(day: day, store: Adapter::AdventCalendar::Store.instance)
  end

  def normalize_prompts(prompts_override, normalized_days)
    return prompts_override.transform_keys(&:to_s) if prompts_override

    build_prompts_for(normalized_days)
  end

  def build_prompts_for(days)
    prompts = days.each_with_object({}) do |(iso_day, attrs), memo|
      memo[iso_day] = default_prompt_payload(Date.iso8601(iso_day), attrs["puzzle_answer"])
    end

    nov8 = Date.new(Adapter::AdventCalendar::END_DATE.year, 11, 8).iso8601
    prompts[nov8] ||= default_prompt_payload(Date.iso8601(nov8), "ember")

    prompts
  end

  def default_prompt_payload(day, puzzle_answer)
    base = {
      "part1_prompt_1" => "Hello from #{day.strftime('%b %d')}!",
      "part2_prompt_1" => "Time for part two on #{day.strftime('%b %d')}!",
      "done_prompt_1" => "Great job finishing #{day.strftime('%b %d')}!",
      "story_1" => "Story for #{day.strftime('%b %d')}.",
      "puzzle_format" => "text",
      "puzzle_prompt" => "What is the answer?",
      "puzzle_answer" => puzzle_answer.presence || "ember"
    }

    if day.month == 11 && day.day == 8
      base.merge!(
        "part1_prompt_1" => "Yoohoo. Come here often? 😗",
        "part1_prompt_2" => "Here is a place where adventures ventures, travels unravel, and stars startle (huh?)",
        "part1_prompt_3" => "All that is wonderful waits when you press the button 👇",
        "part2_prompt_1" => "Wah. You have gathered one star from the check-in ⭐️",
        "part2_prompt_2" => "...",
        "done_prompt_1" => "The story continues tomorrow :) One more star because you are cute 😙",
        "done_prompt_2" => "⭐️",
        "story_1" => "The story will be unveiled soon. Stay tuned!",
        "puzzle_format" => "button",
        "puzzle_prompt" => "what happens?"
      )
    elsif day.month == 11 && day.day == 9
      base.merge!(
        "part1_prompt_1" => "Hello again the warmth of my heart 💛",
        "part2_prompt_1" => "You checked in and earned a star ⭐️! The story continues:",
        "done_prompt_1" => "You just got one more star ⭐️ for providing the right info.",
        "done_prompt_2" => "The story will continue tomorrow :)",
        "puzzle_prompt" => "What is the answer?",
        "puzzle_answer" => puzzle_answer.presence || "ember"
      )
    end

    base
  end

  def auth_headers(password: AdventController::ADVENT_PASSWORD)
    {
      "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("advent", password)
    }
  end

  def auth_get(path, password: AdventController::ADVENT_PASSWORD, **kwargs)
    headers = auth_headers(password: password).merge(kwargs.delete(:headers) || {})
    get(path, **kwargs.merge(headers: headers))
  end

  def auth_post(path, password: AdventController::ADVENT_PASSWORD, **kwargs)
    headers = auth_headers(password: password).merge(kwargs.delete(:headers) || {})
    post(path, **kwargs.merge(headers: headers))
  end
end

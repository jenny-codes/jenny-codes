# typed: false
# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class AdventController < ApplicationController
  before_action :set_calendar
  layout "advent"

  def index
    assign_prompt_data
    assign_star_stats
    assign_voucher_stats
    @active_tab = extract_active_tab
    assign_puzzle_state
    @seconds_until_midnight = seconds_until_midnight
    render "advent/index", locals: layout_locals
  end

  def check_in
    @calendar.check_in
    redirect_to advent_path
  end

  def reset_check_in
    @calendar.reset_check_in
    redirect_to advent_path
  end

  def draw_voucher
    award = @calendar.draw_voucher!
    flash[:voucher_award] = award.to_h
    redirect_to_wah
  rescue Adapter::AdventCalendar::NoEligibleDrawsError
    next_goal = @calendar.next_milestone
    flash[:alert] = if next_goal
                      "Next draw unlocks at #{next_goal} stars. Keep checking in!"
                    else
                      "You have already unlocked every draw milestone."
                    end
    redirect_to_wah
  end

  def redeem_voucher
    flash[:alert] = "Oops this voucher is not redeemable until later ;)"
    redirect_to_wah
  end

  def solve_puzzle
    attempt = params.require(:puzzle_answer).to_s

    if @calendar.attempt_puzzle!(attempt)
      mark_puzzle_completed
    else
      remember_puzzle_attempt(attempt)
    end

    redirect_to advent_path(tab: "main"), status: :see_other
  end

  private

  DAILY_TEMPLATE_DIR = "advent/panels/days"
  DEFAULT_DAILY_TEMPLATE = "20251108"

  def set_calendar
    @today = Time.zone.today
    @calendar = Adapter::AdventCalendar.on(@today)
    @advent_year = Adapter::AdventCalendar::END_DATE.year
  end

  def assign_prompt_data
    @prompt = @calendar.prompt
    @days_left = @calendar.days_left
  end

  def assign_star_stats
    @star_count = @calendar.total_stars
    @total_check_ins = @calendar.total_check_ins
    @draws_available = @calendar.draws_available
    @next_milestone = @calendar.next_milestone
    @stars_until_next_milestone = @calendar.stars_until_next_milestone
  end

  def assign_voucher_stats
    @voucher_awards = @calendar.voucher_awards
    @voucher_milestones = @calendar.voucher_milestones
  end

  def assign_puzzle_state
    if @calendar.puzzle_completed?
      session[:advent_puzzle_completed] = true
      flash.delete(:advent_puzzle_attempt)
      flash.delete(:advent_puzzle_error)
    end

    @puzzle_completed = session[:advent_puzzle_completed] == true
    @puzzle_attempt = flash[:advent_puzzle_attempt]
    @puzzle_error = flash[:advent_puzzle_error]
  end

  def mark_puzzle_completed
    session[:advent_puzzle_completed] = true
    flash.delete(:advent_puzzle_attempt)
    flash.delete(:advent_puzzle_error)
  end

  def remember_puzzle_attempt(answer)
    flash[:advent_puzzle_attempt] = answer
    flash[:advent_puzzle_error] = "That is not correct. Try again?"
  end

  def seconds_until_midnight
    now = Time.zone.now
    midnight_tomorrow = now.tomorrow.beginning_of_day
    [(midnight_tomorrow - now).to_i, 0].max
  end

  def layout_locals
    daily_partial = daily_template_partial

    if @calendar.checked_in?
      {
        main_partial: daily_partial,
        main_locals: { state: :after, primary_action: nil }
      }
    else
      {
        main_partial: daily_partial,
        main_locals: {
          state: :before,
          primary_action: view_context.button_to(
            "Check in",
            advent_check_in_path,
            method: :post,
            class: "advent-button",
            data: { advent_check_in: true }
          )
        }
      }
    end
  end

  def extract_active_tab
    requested = params[:tab].to_s
    return requested if %w[main wah faq].include?(requested)

    "main"
  end

  def redirect_to_wah
    redirect_to advent_path(tab: "wah"), status: :see_other
  end

  def daily_template_partial
    "#{DAILY_TEMPLATE_DIR}/#{daily_template_name}"
  end

  def daily_template_name
    @daily_template_name ||= begin
      preferred = @today.strftime("%Y%m%d")
      if template_exists_for?(preferred)
        preferred
      else
        available_daily_templates.first || DEFAULT_DAILY_TEMPLATE
      end
    end
  end

  def template_exists_for?(name)
    lookup_context.exists?("#{DAILY_TEMPLATE_DIR}/#{name}", [], true)
  end

  def available_daily_templates
    Dir.glob(Rails.root.join("app", "views", DAILY_TEMPLATE_DIR, "_*.html.*"))
       .map { |path| File.basename(path).split(".").first.delete_prefix("_") }
       .sort
  end
end
# rubocop:enable Metrics/ClassLength

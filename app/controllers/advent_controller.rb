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
    @story_state = story_state
    @seconds_until_midnight = seconds_until_midnight
    render "advent/index", locals: layout_locals
  end

  def check_in
    already_checked = @calendar.checked_in?
    @calendar.check_in
    send_check_in_email unless already_checked
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
    result = apply_puzzle_attempt(attempt, persist_flash: !request.format.json?)
    send_puzzle_attempt_email(attempt: attempt, solved: result[:solved])

    respond_to do |format|
      format.html { redirect_to advent_path(tab: "main"), status: :see_other }
      format.json { render_puzzle_attempt_json(result) }
    end
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

  def seconds_until_midnight
    now = Time.zone.now
    midnight_tomorrow = now.tomorrow.beginning_of_day
    [(midnight_tomorrow - now).to_i, 0].max
  end

  def layout_locals
    daily_partial = daily_template_partial
    stage = story_state

    {
      main_partial: daily_partial,
      main_locals: {
        stage: stage,
        primary_action: (stage == :part1 ? check_in_button : nil)
      }.compact
    }
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

  def story_state
    return :completed if @calendar.puzzle_completed?
    return :part2 if @calendar.checked_in?

    :part1
  end

  def check_in_button
    view_context.button_to(
      "Check in",
      advent_check_in_path,
      method: :post,
      class: "advent-button",
      data: { advent_check_in: true }
    )
  end

  def send_check_in_email
    AdventNotifierMailer.check_in(day: @calendar.day).deliver_now
  end

  def apply_puzzle_attempt(attempt, persist_flash: true)
    if @calendar.attempt_puzzle!(attempt)
      mark_puzzle_completed
      { solved: true, message: nil, attempt: attempt }
    else
      error_message = puzzle_error_message
      remember_puzzle_attempt(attempt, persist_flash: persist_flash, message: error_message)
      { solved: false, message: error_message, attempt: attempt }
    end
  end

  def render_puzzle_attempt_json(result)
    if result[:solved]
      render json: { status: "ok", redirect_to: advent_path(tab: "main") }
    else
      render json: {
        status: "error",
        message: result[:message] || puzzle_error_message,
        attempt: result[:attempt]
      }, status: :ok
    end
  end

  def remember_puzzle_attempt(attempt, persist_flash: true, message: puzzle_error_message)
    return unless persist_flash

    flash[:advent_puzzle_attempt] = attempt
    flash[:advent_puzzle_error] = message
  end

  def puzzle_error_message
    "That is not correct. Try again?"
  end

  def send_puzzle_attempt_email(attempt:, solved: false)
    AdventNotifierMailer.puzzle_attempt(day: @calendar.day, attempt: attempt, solved: solved).deliver_now
  end
end
# rubocop:enable Metrics/ClassLength

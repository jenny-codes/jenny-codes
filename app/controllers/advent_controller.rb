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
    assign_secret_state
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
    award = @calendar.redeem_voucher!(params.require(:voucher_id))
    flash[:voucher_redeemed] = award.to_h
    redirect_to_wah
  rescue Adapter::AdventCalendar::VoucherNotFoundError, Adapter::AdventCalendar::VoucherAlreadyRedeemedError => e
    flash[:alert] = e.message
    redirect_to_wah
  end

  def reveal_secret
    secret_code = params.require(:secret_code).to_s

    if secret_code_correct?(secret_code)
      mark_secret_unlocked
    else
      remember_secret_attempt(secret_code)
    end

    redirect_to advent_path(tab: "main"), status: :see_other
  end

  private

  SECRET_CODE = "hooters"

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
    @draws_unlocked = @calendar.draws_unlocked
    @draws_claimed = @calendar.draws_claimed
    @draws_available = @calendar.draws_available
    @next_milestone = @calendar.next_milestone
    @stars_until_next_milestone = @calendar.stars_until_next_milestone
  end

  def assign_voucher_stats
    @voucher_awards = @calendar.voucher_awards
    @voucher_milestones = @calendar.voucher_milestones
  end

  def assign_secret_state
    @secret_revealed = session[:advent_secret_unlocked] == true
    @secret_attempt = flash[:advent_secret_attempt]
    @secret_error = flash[:advent_secret_error]
  end

  def secret_code_correct?(secret_code)
    secret_code.strip.casecmp?(SECRET_CODE)
  end

  def mark_secret_unlocked
    session[:advent_secret_unlocked] = true
    flash.delete(:advent_secret_attempt)
    flash.delete(:advent_secret_error)
  end

  def remember_secret_attempt(secret_code)
    flash[:advent_secret_attempt] = secret_code
    flash[:advent_secret_error] = "That is not correct. Try again?"
  end

  def seconds_until_midnight
    now = Time.zone.now
    midnight_tomorrow = now.tomorrow.beginning_of_day
    [(midnight_tomorrow - now).to_i, 0].max
  end

  def layout_locals
    if @calendar.checked_in?
      { main_partial: "advent/panels/after_main", primary_action: nil }
    else
      {
        main_partial: "advent/panels/before_main",
        primary_action: view_context.button_to(
          "Check in",
          advent_check_in_path,
          method: :post,
          class: "advent-button",
          data: { advent_check_in: true }
        )
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
end
# rubocop:enable Metrics/ClassLength

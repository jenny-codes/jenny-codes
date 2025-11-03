# typed: false
# frozen_string_literal: true

class AdventController < ApplicationController
  before_action :set_calendar
  layout "advent"

  def index
    @prompt = @calendar.prompt
    @days_left = @calendar.days_left
    @star_count = @calendar.total_stars
    @total_check_ins = @calendar.total_check_ins
    @spent_stars = @calendar.spent_stars
    @remaining_stars = @calendar.remaining_stars
    @voucher_awards = @calendar.voucher_awards
    @voucher_cost = @calendar.voucher_cost
    @active_tab = extract_active_tab
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
  rescue Adapter::AdventCalendar::NotEnoughStarsError
    flash[:alert] = "Not enough stars for a draw yet. Keep checking in!"
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

  private

  def set_calendar
    @today = Time.zone.today
    @calendar = Adapter::AdventCalendar.on(@today)
    @advent_year = Adapter::AdventCalendar::END_DATE.year
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

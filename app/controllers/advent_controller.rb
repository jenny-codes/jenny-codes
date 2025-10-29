# typed: false
# frozen_string_literal: true

class AdventController < ApplicationController
  before_action :set_calendar
  layout "advent"

  def index
    @prompt = @calendar.prompt
    @days_left = @calendar.days_left
    @star_count = @calendar.total_stars
    @seconds_until_midnight = @calendar.seconds_until_midnight
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

  private

  def set_calendar
    @today = Date.today
    @calendar = Adapter::AdventCalendar.on(@today)
    @advent_year = Adapter::AdventCalendar::END_DATE.year
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
end

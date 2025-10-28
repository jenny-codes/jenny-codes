# typed: false
# frozen_string_literal: true

class AdventController < ApplicationController
  before_action :set_calendar
  layout 'advent'

  def index
    @prompt = @calendar.prompt
    @days_left = @calendar.days_left
    @star_count = @calendar.total_stars
    render @calendar.template
  end

  def check_in
    @calendar.check_in
    redirect_to advent_path
  end

  private

  def set_calendar
    @today = Date.today
    @calendar = Adapter::AdventCalendar.on(@today)
    @advent_year = Adapter::AdventCalendar::END_DATE.year
  end
end

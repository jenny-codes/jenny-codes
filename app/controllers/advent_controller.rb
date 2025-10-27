# typed: false
# frozen_string_literal: true

class AdventController < ApplicationController
  before_action :set_calendar

  def index
    @days_left = @calendar.days_left
    @prompt = @calendar.prompt
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
  end
end

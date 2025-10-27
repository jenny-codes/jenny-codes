# typed: false
# frozen_string_literal: true

class AdventController < ApplicationController
  def index
    @today = Date.today
    calendar = Adapter::AdventCalendar.on(@today)
    @end_date = calendar.days_left
    @prompt = calendar.prompt
    render calendar.template
  end

  def check_in
  end
end

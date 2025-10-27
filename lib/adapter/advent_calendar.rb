# typed: true
# frozen_string_literal: true

module Adapter
  class AdventCalendar
    END_DATE = Date.parse('2025-12-25')

    #: Date -> self
    def self.on(day)
      new(day)
    end

    def initialize(day)
      @day = day
    end

    def total_stars
      3
    end

    #: -> Integer
    def days_left
      (END_DATE - @day).to_i
    end

    #: -> Bool
    def checked_in? 
      true
    end

    def prompt
      "Wah. You are absolutely right"
    end

    def template
      if checked_in?
        :checked_in
      else
        :index
      end
    end
  end
end

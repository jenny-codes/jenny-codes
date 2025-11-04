# typed: false
# frozen_string_literal: true

class CalendarDay < ApplicationRecord
  validates :day, presence: true, uniqueness: true

  scope :ordered, -> { order(:day) }
end

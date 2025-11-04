# typed: false
# frozen_string_literal: true

class Voucher < ApplicationRecord
  validates :title, :details, presence: true

  scope :latest_first, -> { order(created_at: :desc, id: :desc) }
end

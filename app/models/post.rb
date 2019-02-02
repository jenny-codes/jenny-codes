class Post < ApplicationRecord
  extend FriendlyId
  friendly_id :title, use: :slugged
  validates :title, presence: true
  enum status: [:draft, :published, :idea]

  def normalize_friendly_id(input)
    input.to_s.to_slug.normalize.to_s
  end
end

  
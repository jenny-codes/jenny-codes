class Post < ApplicationRecord
  extend FriendlyId
  friendly_id :title, use: :slugged

  enum status: [:draft, :published]
  validates_presence_of :title

  def normalize_friendly_id(input)
    input.to_s.to_slug.normalize.to_s
  end
end

  
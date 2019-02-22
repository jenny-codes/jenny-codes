class Post < ApplicationRecord
  extend FriendlyId
  friendly_id :title, use: :slugged
  validates :title, presence: true
  enum status: [:draft, :published]

  has_many :taggings
  has_many :tags, through: :taggings

  accepts_nested_attributes_for :tags, reject_if: proc { |tag| tag['text'].blank? }

  default_scope -> { order(created_at: :desc) }

  def normalize_friendly_id(input)
    input.to_s.to_slug.normalize.to_s
  end
end

  
class Post < ApplicationRecord
  enum status: [:draft, :published]
  before_save :init_attributes
  validates_presence_of :title

  scope :published, -> { where( status: 'published' ) }

  private
  def init_attributes
    self.status ||= Post.statuses[:draft]
  end
end

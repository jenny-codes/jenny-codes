class Tag < ApplicationRecord
  has_many :taggings
  has_many :posts, through: :taggings

  validates :text, presence: true, uniqueness: { case_sensitive: false }

  def self.from_array_of_names(tag_names)
    tag_names.map do |name|
      Tag.find_or_create_by(text: name)
    end
  end
end

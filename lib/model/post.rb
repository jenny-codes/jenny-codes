# typed: false
# frozen_string_literal: true

module Model
  POST_ATTRS = [
    :id, :title, :body, :status, :description, :created_at, :updated_at, :slug, :medium_url, :tags,
  ].freeze

  class Post < Data.define(*POST_ATTRS)
    STATUS_DRAFT = "draft"
    STATUS_PUBLISHED = "published"
    STATUS_OF = {
      0 => STATUS_DRAFT,
      1 => STATUS_PUBLISHED,
    }.freeze
  end
end

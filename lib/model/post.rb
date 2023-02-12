# typed: false
# frozen_string_literal: true

module Model
  PostShape = Data.define(
    :id,
    :title,
    :body,
    :status,
    :description,
    :created_at,
    :updated_at,
    :slug,
    :medium_url,
    :tags,
  )

  class Post < PostShape
    STATUS_DRAFT = "draft"
    STATUS_PUBLISHED = "published"
    STATUS_OF = {
      0 => STATUS_DRAFT,
      1 => STATUS_PUBLISHED,
    }.freeze
  end
end

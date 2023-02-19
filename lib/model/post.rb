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
    class Status
      DRAFT = "draft"
      PUBLISHED = "published"

      class << self
        def valid?(status)
          [DRAFT, PUBLISHED].include?(status)
        end
      end
    end

    def published?
      status == Status::PUBLISHED
    end

    def draft?
      status == Status::DRAFT
    end

    def to_json(opts)
      {
        id: id,
        title: title,
        status: status,
        description: description,
        created_at: created_at,
        updated_at: updated_at,
        slug: slug,
        medium_url: medium_url,
        tags: tags,
        body: body,
      }.to_json(opts)
    end
  end
end

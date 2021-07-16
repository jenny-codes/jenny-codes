module Searchable
  extend ActiveSupport::Concern

  included do
    include Elasticsearch::Model
    include Elasticsearch::Model::Callbacks

    # document_type 'post'

    settings index: { number_of_shards: 1 } do
      mappings dynamic: 'false' do
        indexes :title, analyzer: 'english'
        indexes :description, analyzer: 'english'
        indexes :body, analyzer: 'english'
        indexes :tags, type: :object do
          indexes :text
        end
      end
    end

    # Overriding serializer
    def as_indexed_json(**opts)
      as_json(only: [:title, :description, :body],
              include: { tags: { only: :text } })
    end
  end
end

# typed: true
# frozen_string_literal: true

module Adapter
  class PostsRepo
    extend T::Sig

    class RecordNotFound < StandardError; end

    sig { params(posts: T::Array[Model::Post]).void }
    def initialize(posts)
      @posts = posts.sort_by(&:id)
    end

    sig { params(tag: T.nilable(String)).returns(T::Array[Model::Post]) }
    def list_published_order_by_id_desc(tag: nil)
      select_fn = if tag && !tag.empty?
        ->(post) { post.status == Model::Post::STATUS_PUBLISHED && post.tags.include?(tag) }
      else
        ->(post) { post.status == Model::Post::STATUS_PUBLISHED }
      end

      @posts.select(&select_fn).reverse
    end

    sig { returns(T::Array[Model::Post]) }
    def list_draft_order_by_id_desc
      @posts.select { _1.status == Model::Post::STATUS_DRAFT }.reverse
    end

    sig { params(id: Integer).returns(T.any(Model::Post, RecordNotFound)) }
    def find_by_id(id)
      @posts.detect { _1.id == id } || RecordNotFound.new("Cannot find post with id=#{id}")
    end

    sig { params(slug: String).returns(T.any(Model::Post, RecordNotFound)) }
    def find_by_slug(slug)
      @posts.detect { _1.slug == slug } || RecordNotFound.new("Cannot find post with slug=#{slug}")
    end

    sig { params(id: Integer).returns(T.any(Model::Post, RecordNotFound)) }
    def next_of(id)
      next_index = @posts.index { _1.id == id } + 1
      next_index == @posts.count ? @posts.first : @posts[next_index]
    end

    sig { params(id: Integer).returns(T.any(Model::Post, RecordNotFound)) }
    def prev_of(id)
      prev_index = @posts.index { _1.id == id } - 1
      prev_index == -1 ? @posts.last : @posts[prev_index]
    end
  end
end

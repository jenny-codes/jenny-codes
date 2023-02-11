# frozen_string_literal: true

class PostsController < ApplicationController
  before_action :authenticate,    except: %i[index all show]

  USERS = { ENV['admin_username'] => ENV['admin_password'] }.freeze
  POSTS_PER_PAGE = 10

  include Caching

  # Default view, now only when tag is clicked
  def index
    @posts_in_pages = cache('post_index', tag: params[:tag] || 'none') do
      posts = PostArchive.list_published_order_by_id_desc(params[:tag])

      posts.in_groups_of(POSTS_PER_PAGE, false)
    end

    @pagination = {
      curr_page: params[:page].try(:to_i) || 1,
      total_pages: @posts_in_pages.count
    }

    expires_in(10.minutes, public: true)
  end

  # Simplified view
  def all
    @posts = cache('post_all') do
      PostArchive.list_published_order_by_id_desc
    end

    expires_in(10.minutes, public: true)
  end

  # Internal view
  def list
    @posts = PostArchive.list_published_order_by_id_desc
    @draft = PostArchive.list_draft_order_by_id_desc
  end

  def show
    raise 'need to support id field' if /^\d+$/.match?(params[:id])

    @post, @adjacent_posts = cache('post_show', id: params[:id]) do
      current_post = PostArchive.find_by_slug(params[:id])
      next_post    = PostArchive.next_of(current_post.id)
      prev_post    = PostArchive.prev_of(current_post.id)
      [current_post, { next: next_post, prev: prev_post }]
    end

    expires_in(10.minutes, public: true)
  end

  private

  def authenticate
    return unless Rails.env.production?

    authenticate_or_request_with_http_digest do |username|
      USERS[username]
    end
  end
end

# frozen_string_literal: true

class PostsController < ApplicationController
  before_action :authenticate,    except: %i[index all show]

  USERS = { ENV['admin_username'] => ENV['admin_password'] }.freeze
  POSTS_PER_PAGE = 10

  include Caching

  # Default view, now only when tag is clicked
  def index
    @posts_in_pages = cache('post_index', tag: params[:tag] || 'none') do
      posts_rel = Post.includes(:tags).published.recent
      posts_rel = posts_rel.where(tags: { text: params[:tag] }) if params[:tag]

      posts_rel.in_groups_of(POSTS_PER_PAGE, false)
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
      Post.published.recent.to_a
    end

    expires_in(10.minutes, public: true)
  end

  # Internal view
  def list
    @posts = Post.published.recent
    @draft = Post.draft
  end

  def show
    @post, @adjacent_posts = cache('post_show', id: params[:id]) do
      current_post = Post.includes(:tags).friendly.find(params[:id])
      next_post    = current_post.next
      prev_post    = current_post.previous
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

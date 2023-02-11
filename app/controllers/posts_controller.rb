# frozen_string_literal: true

class PostsController < ApplicationController
  before_action :authenticate,    except: %i[index all show]
  before_action :find_post,       only: %i[edit update destroy]

  USERS = { ENV['admin_username'] => ENV['admin_password'] }.freeze
  POSTS_PER_PAGE = 10

  include Caching

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

  def all
    @posts = cache('post_all') do
      Post.published.recent.to_a
    end

    expires_in(10.minutes, public: true)
  end

  def list
    @posts = Post.published.recent
    @draft = Post.draft
  end

  def new
    @post = Post.new
    build_selection_for_form
    render template: 'posts/form'
  end

  def edit
    build_selection_for_form
    render template: 'posts/form'
  end

  def create
    post_params = if params[:post][:file]
                    post_params_from_file
                  else
                    post_params_from_form
                  end

    Post.create!(post_params)
    redirect_to list_posts_path, info: 'Created successfully :)'
  end

  def update
    post_params = if params[:status]
                    params[:status]
                  elsif params[:post][:file]
                    post_params_from_file
                  else
                    post_params_from_form
                  end

    @post.update!(post_params)
    redirect_to post_path, info: 'Updated successfully :)'
  end

  def destroy
    @post.destroy
    redirect_to list_posts_path
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

  def find_post
    @post = Post.friendly.find(params[:id])
  end

  def post_params_from_file
    file = params.require(:post).permit(:file)[:file]
    file.open
    html = ::MarkdownPostProcessor.get_html_from_md(file.read)
    file.close

    tag_names = MarkdownPostProcessor.post_tag_names_for(html)

    {
      title: MarkdownPostProcessor.post_title_for(html),
      description: MarkdownPostProcessor.post_description_for(html),
      body: MarkdownPostProcessor.post_body_for(html),
      tags: Tag.from_array_of_names(tag_names),
      status: :draft
    }
  end

  def post_params_from_form
    post_params = params.require(:post).permit(:title, :body, :status, :description, :medium_url, :slug)

    tags = tag_params
    post_params.merge!(tags:) if tags

    post_params
  end

  def tag_params
    tag_names = params[:tags] | params[:new_tags]
    return if tag_names.blank?

    Tag.from_array_of_names(tag_names).compact
  end

  def authenticate
    return unless Rails.env.production?

    authenticate_or_request_with_http_digest do |username|
      USERS[username]
    end
  end

  def build_selection_for_form
    @tags = Tag.all
    @status_list = [%w[草稿 draft], %w[發佈 published]]
  end
end

class PostsController < ApplicationController
  before_action :build_selection, only: [:new, :edit]
  before_action :authenticate,    except: [:index, :show, :upcoming]
  before_action :build_posts,     only: [:list, :upcoming]
  before_action :build_post,      only: [:new, :create]
  before_action :find_post,       only: [:show, :edit, :update, :destroy]
  before_action :build_tags,      only: [:create, :update]

  USERS = { ENV["admin_username"] => ENV["admin_password"] }
  MEDIUM_ACCOUNT = 'jinghua.shih'

  def initialize
    @medium_cli = Medium.new
    super
  end

  def index
    # if a tag is selected, render only the posts with that tag
    # else render all published posts
    raw_posts = if params[:tag]
      Post.joins(:tags).where(tags: {text: params[:tag]})
    else
      Post.published
    end

    # pagination
    posts_with_page = raw_posts.in_groups_of(2, false)

    @posts = {
      total_pages: posts_with_page.count,
      curr_page: params[:page].try(:to_i) || 1,
    }
    @posts[:content] = posts_with_page[@posts[:curr_page]]
  end

  def list
  end

  def new
    render template: 'posts/form'
  end

  def edit
    render template: 'posts/form'
  end

  def create 
    @post.save!
    redirect_to list_posts_path
  end

  def update
    @post.update!(post_params)
    redirect_to post_path, info: 'You are good to go!'
  end

  def destroy
    @post.destroy
    redirect_to list_posts_path
  end

  def upcoming
  end

  def sync_with_medium

    # if there's a specific link 
    if params[:commit] == 'import'
      create_or_update(@medium_cli.parse_url(params[:medium_url]))
    # update from lastest post
    else
      create_or_update(@medium_cli.last_post_by(MEDIUM_ACCOUNT))
    end
    redirect_to posts_path
  end

  private

    def build_post
      @post = Post.new(post_params)
    end

    def build_posts
      @posts = Post.published
      @draft = Post.draft
    end

    def find_post
      @post = Post.friendly.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def post_params
      if params[:post]
        params.require(:post).permit(:title, :body, :status, :description, :medium_url)
      elsif params[:status]
        params.permit(:status)
      else
        Hash.new
      end
    end

    def authenticate
      if Rails.env.production?
        authenticate_or_request_with_http_digest do |username|
          USERS[username]
        end
      end
    end

    def build_selection
      @tags = Tag.all
      @status_list = [['草稿', 'draft'], ['發佈', 'published']]
    end

    def create_or_update(medium_post)
      Post.find_or_initialize_by(medium_url: medium_post[:medium_url]).tap do |post|
        post.title       = medium_post[:title]
        post.body        = medium_post[:body]
        post.status      = :published
        post.description = medium_post[:description]
        post.save!
      end
    end

    def build_tags
      if params[:tags]
        # clear un-select tags first
        @post.tags.each do |tag|
          unless params[:tags].include?(tag.id.to_s)
            Tagging.find_by(post_id: @post.id, tag_id: tag.id).delete
          end
        end

        # then add new tags
        params[:tags].map(&:to_i).each do |checkbox_tag_id|
          tag_id_set = @post.tags.pluck(:id)
          unless tag_id_set.include?(checkbox_tag_id)
            Tagging.create(post_id: @post.id, tag_id: checkbox_tag_id)
          end
        end
      end

      # the newly typed tags
      if params[:new_tags]
        params[:new_tags].each do |new_tag|
          next if new_tag.blank?
          @post.tags.create(text: new_tag)
        end
      end
    end
end

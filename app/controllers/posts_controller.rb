class PostsController < ApplicationController
  before_action :build_selection, only: [:new, :edit]
  before_action :authenticate,    except: [:index, :show, :upcoming]
  before_action :build_posts,     only: [:index, :list, :upcoming]
  before_action :build_post,      only: [:new, :create]
  before_action :find_post,       only: [:show, :edit, :update, :destroy]

  USERS = { ENV["admin_username"] => ENV["admin_password"] }
  MEDIUM_ACCOUNT = 'jinghua.shih'

  def index
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
    redirect_to @post, notice: 'You are good to go!'
  end

  def destroy
    @post.destroy
    redirect_to list_posts_path
  end

  def upcoming
  end

  def sync_with_medium
    medium_post = Medium.new(MEDIUM_ACCOUNT).last_post
    Post.find_or_initialize_by(title: medium_post[:title]).tap do |post|
      post.description = medium_post[:description]
      post.medium_url  = medium_post[:url]
      post.status      = :published
      post.body        = medium_post[:body]
      post.save!
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
        params.require(:post).permit(:title, :body, :status, :description)
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
      @status_list = [['草稿', 'draft'], ['發佈', 'published']]
    end
end

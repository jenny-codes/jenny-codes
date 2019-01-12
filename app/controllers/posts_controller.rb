class PostsController < ApplicationController
  before_action :build_selection, only: [:new, :edit]
  before_action :authenticate,    except: [:index, :show]
  before_action :build_post,      only: [:new, :create]
  before_action :set_post,        only: [:show, :edit, :update, :destroy]

  USERS = { ENV["admin_username"] => ENV["admin_password"] }

  def index
    @posts = Post.published.order('created_at DESC')
  end

  def list
    @posts = Post.all
  end

  def new
    render template: 'posts/form'
  end

  def edit
    render template: 'posts/form'
  end

  def create    
    if @post.save
      redirect_to posts_list_path, notice: '檢查錯字了嗎'
    else 
      redirect_to posts_list_path, error: '你做了什麼'
    end
  end

  def update
    if @post.update(post_params)
      redirect_to @post, notice: '更新好ㄌ'
    else
      render :edit 
    end
  end

  def destroy
    @post.destroy
    redirect_to posts_url, notice: '成功毀滅了'
  end

  def idea
    @ideas = Post.idea
  end

  private

    def build_post
      @post = Post.new(post_params)
    end

    def set_post
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
      authenticate_or_request_with_http_digest do |username|
        USERS[username]
      end
    end

    def build_selection
      @status_list = [['草稿', 'draft'], ['發佈', 'published']]
    end
end

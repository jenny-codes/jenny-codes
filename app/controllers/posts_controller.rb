class PostsController < ApplicationController
  before_action :build_selection, only: [:new, :edit]
  before_action :authenticate, except: [:index, :show]
  before_action :set_post, only: [:show, :edit, :update, :destroy]

  USERS = { ENV["admin_username"] => ENV["admin_password"] }
  # GET /posts
  # GET /posts.json
  def index
    @posts = Post.published.order('created_at DESC')
  end

  def list
    @posts = Post.all
  end

  def show
  end

  def new
    @post = Post.new
    render template: 'posts/form'
  end

  # GET /posts/1/edit
  def edit
    render template: 'posts/form'
  end

  def create
    @post = Post.new(post_params)
    
    if @post.save
      flash[:notice] = "Yet another article towards greateness is created. Now get yor ass up and write another post. Hurry!"
      redirect_to posts_list_path
    else 
      flash[:eror] = "Post not created. Did you forget something?"
      redirect_to posts_list_path 
    end
  end

  def update
    if @post.update(post_params)
      redirect_to @post, notice: 'Post was successfully updated.'
    else
      render :edit 
    end
  end

  def destroy
    @post.destroy
    respond_to do |format|
      format.html { redirect_to posts_url, notice: 'Post was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private

    def set_post
      @post = Post.find_by(id: params[:id]) || Post.new
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def post_params
      if params[:post]
        params.require(:post).permit(:title, :body, :status, :description)
      elsif params[:status]
        params.permit(:status)
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

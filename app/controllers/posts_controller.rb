class PostsController < ApplicationController
  before_action :authenticate,    except: [:index, :show]
  before_action :find_post,       only: [:show, :edit, :update, :destroy]

  USERS = { ENV["admin_username"] => ENV["admin_password"] }
  POSTS_PER_PAGE = 5

  def index
    # if a tag is selected, render only the posts with that tag
    # else render all published posts
    raw_posts = if params[:tag]
      Post.includes(:tags).where(tags: {text: params[:tag]}).recent
    else
      Post.includes(:tags).published.recent
    end

    # pagination
    posts_with_page = raw_posts.in_groups_of(POSTS_PER_PAGE, false)

    @posts = {
      total_pages: posts_with_page.count,
      curr_page: params[:page].try(:to_i) || 1,
    }
    @posts[:content] = posts_with_page[@posts[:curr_page] - 1]
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
    @prev_post = @post.previous
    @next_post = @post.next
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

      tag_names = ::MarkdownPostProcessor.post_tag_names_for(html)

      {
        title:       ::MarkdownPostProcessor.post_title_for(html),
        description: ::MarkdownPostProcessor.post_description_for(html),
        body:        ::MarkdownPostProcessor.post_body_for(html),
        tags:        Tag.from_array_of_names(tag_names),
        status:      :draft,
      }
    end

    def post_params_from_form
      post_params = params.require(:post).permit(:title, :body, :status, :description, :medium_url, :slug)
      
      tags = tag_params
      post_params.merge!(tags: tags) if tags

      post_params
    end

    def tag_params
      tag_names = params[:tags] | params[:new_tags]
      return if tag_names.blank?

      Tag.from_array_of_names(tag_names).compact
    end

    def authenticate
      if Rails.env.production?
        authenticate_or_request_with_http_digest do |username|
          USERS[username]
        end
      end
    end

    def build_selection_for_form
      @tags = Tag.all
      @status_list = [['草稿', 'draft'], ['發佈', 'published']]
    end
end

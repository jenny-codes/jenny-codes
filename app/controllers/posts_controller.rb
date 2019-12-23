class PostsController < ApplicationController
  before_action :authenticate,    except: [:index, :show]

  before_action :build_post,      only: [:new, :create]
  before_action :find_post,       only: [:show, :edit, :update, :destroy]
  before_action :build_tags,      only: [:create, :update]

  USERS = { ENV["admin_username"] => ENV["admin_password"] }
  POSTS_PER_PAGE = 5

  def index
    # if a tag is selected, render only the posts with that tag
    # else render all published posts
    raw_posts = if params[:tag]
      Post.joins(:tags).where(tags: {text: params[:tag]}).recent
    else
      Post.published.recent
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
    build_selection_for_form
    render template: 'posts/form'
  end

  def edit
    build_selection_for_form
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

  def show
    @prev_post = @post.previous
    @next_post = @post.next
  end

  def parse_uploaded_file
    pars = params.permit(:file, :id)
    post_attrs = post_attrs_from_md_file(pars['file'].open.read)
    pars['file'].close

    if params[:id].present?
      Post.find(pars[:id].to_i).update!(post_attrs)
    else
      Post.create!(post_attrs)
    end

    redirect_to list_posts_path
  end

  private

    def build_post
      @post = Post.new(post_params)
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

    def build_selection_for_form
      @tags = Tag.all
      @status_list = [['草稿', 'draft'], ['發佈', 'published']]
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

    def post_attrs_from_md_file(file)
      data = Redcarpet::Markdown.new(Redcarpet::Render::HTML, fenced_code_blocks: true).render(file)
      html = Nokogiri::HTML(data)
      html.search('img').each do |img|
        img['class'] = 'lazy img-fluid'
        img['data-src'] = img['src']
        img.remove_attribute('src')
      end

      {
        title: html.search('h1').text,
        body: html.search('body').children[1..-1],
        status: :draft
      }
    end
end

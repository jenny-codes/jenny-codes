# typed: false
# frozen_string_literal: true

require "test_helper"

class PostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @post = PostArchive.list_published_order_by_id_desc.first
  end

  teardown do
    Rails.cache.clear
  end

  test "should get index" do
    get posts_url
    assert_response :success
  end

  test "should get all" do
    get all_posts_url
    assert_response :success
  end

  test "should get list" do
    get list_posts_url
    assert_response :success
  end

  test "should show post" do
    get post_url(@post.slug)
    assert_response :success
  end

  test "cache works for index" do
    get posts_url

    assert_cache_queries(1) do
      get posts_url
    end
  end

  test "cache works for post_all" do
    get all_posts_url

    assert_cache_queries(1) do
      get all_posts_url
    end
  end

  test "cache works for post_show" do
    get post_url(@post.slug)

    assert_cache_queries(1) do
      get post_url(@post.slug)
    end
  end
end

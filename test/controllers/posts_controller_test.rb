# typed: false
# frozen_string_literal: true

require "test_helper"

class PostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @post = posts(:one)
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
    get post_url(@post)
    assert_response :success
  end

  test "cache works for index" do
    get posts_url

    assert_db_queries(0) do
      assert_cache_queries(1) do
        get posts_url
      end
    end
  end

  test "cache works for post_all" do
    get all_posts_url

    assert_db_queries(0) do
      assert_cache_queries(1) do
        get all_posts_url
      end
    end
  end

  test "cache works for post_show" do
    get post_url(@post)

    assert_db_queries(0) do
      assert_cache_queries(1) do
        get post_url(@post)
      end
    end
  end
end

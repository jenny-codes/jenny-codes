# frozen_string_literal: true

require 'test_helper'

class PostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @post = posts(:one)
  end

  teardown do
    Rails.cache.clear
  end

  test 'should get index' do
    get posts_url
    assert_response :success
  end

  test 'should get new' do
    get new_post_url
    assert_response :success
  end

  test 'should create post' do
    assert_difference('Post.count') do
      post posts_url,
           params: { post: { body: @post.body, description: @post.description, status: @post.status,
                             title: @post.title } }
    end

    assert_redirected_to list_posts_url
  end

  test 'should show post' do
    get post_url(@post)
    assert_response :success
  end

  test 'should get edit' do
    get edit_post_url(@post)
    assert_response :success
  end

  test 'should update post' do
    patch post_url(@post),
          params: { post: { body: @post.body, description: @post.description, status: @post.status,
                            title: @post.title } }
    assert_redirected_to post_url(@post)
  end

  test 'should destroy post' do
    assert_difference('Post.count', -1) do
      delete post_url(@post)
    end

    assert_redirected_to list_posts_url
  end

  test 'cache works for index' do
    get posts_url

    assert_db_queries(0) do
      assert_cache_queries(1) do
        get posts_url
      end
    end
  end

  test 'cache works for post_all' do
    get all_posts_url

    assert_db_queries(0) do
      assert_cache_queries(1) do
        get all_posts_url
      end
    end
  end

  test 'cache works for post_show' do
    get post_url(@post)

    assert_db_queries(0) do
      assert_cache_queries(1) do
        get post_url(@post)
      end
    end
  end
end

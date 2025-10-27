# typed: false
# frozen_string_literal: true

require "test_helper"

class StaticsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get root_url
    assert_response :success
  end

  test "should get about" do
    get about_url
    assert_response :success
  end

  test "should get talks" do
    get talks_url
    assert_response :success
  end

  test "should get chloe" do
    get chloe_url
    assert_response :success
  end

  test "should get limuy" do
    get limuy_url
    assert_response :success
  end
end

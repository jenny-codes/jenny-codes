# typed: false
# frozen_string_literal: true

require "model/post"
require "adapter/posts_repo"

path = "#{Rails.root}/lib/data/posts.json"
posts = JSON.parse(File.read(path), symbolize_names: true).map do |post_hash|
  status = post_hash[:status]
  raise("Status '#{status}' for post '#{post_hash[:id]}' is not recognized.") unless Model::Post::Status.valid?(status)

  Model::Post.new(
    id: post_hash[:id],
    title: post_hash[:title],
    body: post_hash[:body],
    status: status,
    description: post_hash[:description],
    created_at: Time.parse(post_hash[:created_at]),
    updated_at: Time.parse(post_hash[:updated_at]),
    slug: post_hash[:slug],
    medium_url: post_hash[:medium_url],
    tags: post_hash[:tags]
  )
end

PostArchive = Adapter::PostsRepo.new(posts)

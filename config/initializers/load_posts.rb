# frozen_string_literal: true

require 'model/post'
require 'adapter/posts_repo'

path = "#{Rails.root}/lib/assets/posts.json"
posts = JSON.parse(File.read(path), symbolize_names: true).map do |post_hash|
  Model::Post.new(
    id: post_hash[:id],
    title: post_hash[:title],
    body: post_hash[:body],
    status: Model::Post::STATUS_OF[post_hash[:status]],
    description: post_hash[:description],
    created_at: DateTime.parse(post_hash[:created_at]),
    updated_at: DateTime.parse(post_hash[:updated_at]),
    slug: post_hash[:slug],
    medium_url: post_hash[:medium_url],
    tags: []
  )
end

PostArchive = Adapter::PostsRepo.new(posts)

# typed: false
# frozen_string_literal: true

# desc "Import tags through tagging to posts"
task import_tags: :environment do
  taggings = JSON.parse(File.read("/Users/jennyshih/Desktop/notes/post_archive/taggings.json"), symbolize_names: true)
  tags = JSON.parse(File.read("/Users/jennyshih/Desktop/notes/post_archive/tags.json"), symbolize_names: true)

  updated_posts = taggings.group_by { _1[:post_id] }.filter_map do |post_id, taggings|
    post = PostArchive.find_by_id(post_id)
    next if post.is_a?(Adapter::PostsRepo::RecordNotFound)

    tag_ids = taggings.map { _1[:tag_id] }
    tag_names = tags.select { |t| tag_ids.include?(t[:id]) }.map { _1[:text] }
    Model::Post.new(**post.to_h, tags: tag_names)
  end.sort_by(&:id)

  File.open("updated_posts2.json", "w") do |f|
    JSON.dump(updated_posts, f)
  end
end

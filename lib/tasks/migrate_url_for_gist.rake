# frozen_string_literal: true

desc 'Update urls for gist from jing-jenny-shih to jenny-code'
task migrate_url_for_gist: :environment do
  Post.all.each do |post|
    post.update!(
      body: post.body.gsub('gist.github.com/jing-jenny-shih', 'gist.github.com/jenny-codes')
    )
    puts "done for #{post.title}"
  end
end

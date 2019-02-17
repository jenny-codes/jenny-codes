module PostsHelper
  def medium_url(post)
    if post.medium_url
      [URI.decode(post.medium_url).match(/(?<=shih\/).*/)[0].truncate(20), post.medium_url]
    else
      ["NO DATA"]
    end
  end
end

module PostsHelper
  def medium_url(post)
    if post.medium_url
      if url = URI.decode(post.medium_url).match(/(?<=shih\/).*/)
        [url[0].truncate(20), post.medium_url]
      else
        ['WEIRD']
      end
    else
      ["NO DATA"]
    end
  end
end

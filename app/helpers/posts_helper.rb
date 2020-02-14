module PostsHelper
  def medium_url(post)
    if post.medium_url.present?
      if url = URI.decode(post.medium_url).match(/(?<=shih\/).*/)
        [url[0].truncate(20), post.medium_url]
      end
    else
      ["NO DATA"]
    end
  end

  def render_section_subheading
    p = /[^\/]*$/.match(request.path)[0].upcase
    p.present? ? p : nil
  end

  def id_for(post)
    post.friendly_id.presence || post.id
  end
end

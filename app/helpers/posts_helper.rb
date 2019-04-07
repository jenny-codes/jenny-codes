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

  def render_subheading(default)
    path =  /[^\/]*$/.match(request.path)[0].upcase
    path.blank? ? default : path 
  end

  # def title_with_line_break(title)
  #   return unless title

  #   break_pos = title.index(']')
  #   return title unless break_pos

  #   title.insert(break_pos + 2, "\n").html_safe
  # end
end

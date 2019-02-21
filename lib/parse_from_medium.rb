require 'open-uri'

class Medium 

  # return a list of post-urls for a given account
  def all_posts_by(account)
    urls = []
    homepage = Nokogiri::HTML(open("https://medium.com/@#{account}/"))
    homepage.search('a h1:first-of-type').each do |title|
      urls << clean_url(title.ancestors('a')[0]['href'])
    end
    urls
  end

  def last_post_by(account)
    parse_url(all_posts_by(account)[0])
  end

  def parse_url(url)
    content     = Nokogiri::HTML(open(url)).search('div.section-inner')
    title       = content.search('h1').text
    body        = normalize(content)
    description = body.children.first.content 
    footer      = '<p>文章同步發表於 <a href="https://medium.com/@jinghua.shih">Medium</a>。'

    body.children.first.remove

    {
            title: title,   
       medium_url: url,          
      description: description,
             body: body.to_s + footer
    }
  end

  private
    def normalize post

      post.children[0..1].remove
      post.children.each do |seg|
        seg.remove_attribute('id')
        seg.remove_attribute('name')
        seg.remove_attribute('class')

        if seg.name == 'figure'
          if seg.search('img').empty?
            clean_gist_block(seg)
          else 
            clean_img_block(seg)
          end
        elsif seg.name == 'div'
          clean_ref_block(seg)
        end
      end
      post.children
    end

    def clean_img_block figure
      figure.add_class('text-center')
      img = figure.first_element_child.children.search('img')[0]
      # img.remove_attribute('class')
      img.remove_attribute('data-width')
      img.remove_attribute('data-height')
      img.remove_attribute('data-image-id')
      img.remove_attribute('data-is-featured')

      img['class'] = 'lazy'
      img['data-src'] = img['src']
      img.remove_attribute('src')

      figure.first_element_child.swap(img)
    end

    def clean_gist_block figure
      figure.add_class('text-center')
      url = figure.search('a').attr('href').content + '.js'
      embed = figure.add_next_sibling("<script src=#{url}></script>")
      figure.first_element_child.swap(embed)
    end

    def clean_ref_block div
      div.search('a em').remove
    end

    def clean_url url
      /.*(?=\?)/.match(url)[0]
    end
end

# Medium.new('jinghua.shih').last_post
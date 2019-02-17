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
    description = body.search('p').first.content 

    {
            title: title,   
       medium_url: url,          
      description: description,
             body: body
    }
  end

  private
    def normalize post
      post.children[0..1].remove
      post.children.each do |seg|
        seg.remove_attribute('name')
        seg.remove_attribute('id')
        seg.remove_attribute('class')
        if seg.name == 'figure'
          clean_img_block(seg)
        elsif seg.name == 'div'
          clean_ref_block(seg)
        end
      end
      post.children
    end

    def clean_img_block figure
      img = figure.first_element_child.children.search('img')[0]
      # img['class'] = 'lazy'
      # img['data-src'] = img['src']
      # img.remove_attribute('src')
      figure.first_element_child.swap(img)
    end

    def clean_ref_block div
      div.search('a em').remove
    end

    def clean_url url
      /.*(?=\?)/.match(url)[0]
    end
end

# Medium.new('jinghua.shih').last_post
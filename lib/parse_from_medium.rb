require 'open-uri'

class Medium 
  def initialize(account)
    @homepage = Nokogiri::HTML(open("https://medium.com/@#{account}/"))
  end

  def last_post
    last_post = {
        url: clean_url(@homepage.search('div.h a')[2].attribute('href').value),
      title: @homepage.xpath("//h1")[1].content
    }

    last_post[:body] = normalize(Nokogiri::HTML(open(last_post[:url])).search('div.section-inner'))
    last_post[:description] = last_post[:body].search('p').first.content  
    last_post  
  end

  private
    def normalize post
      post.children[0..1].remove
      segments = post.children
      segments.search('figure').each { |fig| clean_img_block(fig) }
      segments.search('a em').remove
      segments
    end

    def clean_img_block figure
      img = figure.first_element_child.children.search('img')[0]
      # img['class'] = 'lazy'
      # img['data-src'] = img['src']
      # img.remove_attribute('src')
      figure.first_element_child.swap(img)
    end

    def clean_url url
      /.*(?=\?)/.match(url)[0]
    end
end

# Medium.new('jinghua.shih').last_post
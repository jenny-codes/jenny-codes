require 'open-uri'

class Medium 
  def initialize(account)
    @homepage = Nokogiri::HTML(open("https://medium.com/@#{account}/"))
  end

  def last_post
    last_post = {
        url: @homepage.search('div.h a')[2].attribute('href').value,
      title: @homepage.xpath("//h1")[1].content
    }

    last_post[:body] = clean(Nokogiri::HTML(open(last_post[:url])).search('div.section-inner'))
    last_post[:subtitle] = last_post[:body].search('p').first.content  
    last_post  
  end

  def clean post
    post.children[0..1].remove
    segments = post.children
    segments.search('figure').each { |fig| clean_img(fig) }
    segments.search('a em').remove
    segments
  end

  private
    def clean_img figure
      img = figure.first_element_child.children.search('img')
      figure.first_element_child.swap(img)
    end
end

# Medium.new('jinghua.shih').last_post
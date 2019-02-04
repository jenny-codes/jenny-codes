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

    last_post[:body] = Nokogiri::HTML(open(last_post[:url])).search('div.section-inner').tap do |body|
      body.children[0..1].remove
      body.children.remove_class
    end

    last_post[:subtitle] = last_post[:body].children[0].content    
    last_post  
  end
end
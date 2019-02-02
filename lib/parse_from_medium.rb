require 'open-uri'

class Medium 
  def initialize(account)
    homepage = Nokogiri::HTML(open("https://medium.com/@#{account}/"))
    @last_post = {
        url: homepage.search('div.h a')[2].attribute('href').value,
      title: homepage.xpath("//h1")[1].content
    }
  end

  def synchronize_last_post
    return if Post.last.title == @last_post[:title]
    @last_post[:body] = Nokogiri::HTML(open(@last_post[:url])).search('div.section-inner')

    # clean up a bit 
    @last_post[:body].tap do |body|
      body.children[0..1].remove
      body.children.remove_class
    end

    @last_post[:description] = @last_post[:body].children[0].content

    Post.create(
            title: @last_post[:title],
             body: @last_post[:body],
           status: :published,
      description: @last_post[:description]
    )      
  end
end
module MarkdownPostProcessor

  module_function

  def get_html_from_md(input)
    html_raw = Redcarpet::Markdown.new(
      CustomHtmlRender, 
      fenced_code_blocks: true,
      strikethrough: true,
      autolink: true
    ).render(input)

    Nokogiri::HTML(html_raw)
  end

  def post_title_for(html)
    html.search('h1').text
  end

  def post_description_for(html)
    html.search('p').find { |p| p.text.present? }.text
  end

  def post_body_for(html)
    # remove 
    # 1. title
    # 2. first paragraph (description)
    # 3. blank leading paragraphs
    # 4. tags (marked as h5)
    html.search('body').children.tap do |nodes|
      nodes.delete(nodes.search('h1').first)
      nodes.search('h5').each { |tag_node| nodes.delete(tag_node) }
      nodes.delete(nodes.find { |p| p.text.present? })
      nodes.drop_while(&:blank?)
    end
  end

  def post_tag_names_for(html)
    html.search('h5').map(&:text)
  end
 
  class CustomHtmlRender < ::Redcarpet::Render::HTML
    def image(link, title, alt_text)
      %(<img alt="#{alt_text}" class="lazy img-fluid" data-src="#{link}">)
    end

    def header(text, header_level)
      %(<h#{header_level} id=#{text.parameterize}>#{text}</h#{header_level}>)
    end
  end
end

# typed: false
# frozen_string_literal: true

module PostsHelper
  def render_section_subheading
    p = %r{[^/]*$}.match(request.path)[0].upcase
    p.present? ? p : nil
  end
end

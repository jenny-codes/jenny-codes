# typed: false
# frozen_string_literal: true

class ApplicationController < ActionController::Base
  protect_from_forgery with: :null_session
  before_action :ensure_domain

  private

  def ensure_domain
    return if Rails.env.development? || Rails.env.test? || request.env["HTTP_HOST"] == "jenny.sh"

    redirect_to("https://jenny.sh#{request.env['REQUEST_PATH']}", status: 301)
  end
end

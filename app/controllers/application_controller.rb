# frozen_string_literal: true

class ApplicationController < ActionController::Base
  protect_from_forgery with: :null_session
  before_action :ensure_domain

  private

  def ensure_domain
    return if Rails.env.development? || request.env['HTTP_HOST'] == 'codecharms.me'

    redirect_to "https://codecharms.me#{request.env['REQUEST_PATH']}", status: 301
  end
end

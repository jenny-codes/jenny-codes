class ApplicationController < ActionController::Base
  include Error::ErrorHandler
  protect_from_forgery with: :exception
  before_action :ensure_domain

  private
  def ensure_domain
    if request.env['HTTP_HOST'] == "jennycodes.herokuapp.com"
      redirect_to "https://jennycodes.me#{request.env['REQUEST_PATH']}", status: 301
    end
  end

end

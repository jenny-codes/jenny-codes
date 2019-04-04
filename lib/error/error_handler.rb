# Error module to Handle errors globally
# include Error::ErrorHandler in application_controller.rb
# Only rescue errors on production.
module Error
  module ErrorHandler
    def self.included(clazz)
      clazz.class_eval do
        if Rails.env.production?
          rescue_from StandardError, with: :standard_error
        end
      end
    end

    private

    def standard_error(_e)
      Rails.logger.error _e.message
      Rails.logger.error _e.backtrace.join("\n")
      flash[:danger] = "Oops! #{_e}"
      redirect_back fallback_location: root_path
    end
  end
end
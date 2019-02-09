# Error module to Handle errors globally
# include Error::ErrorHandler in application_controller.rb
module Error
  module ErrorHandler
    def self.included(clazz)
      clazz.class_eval do
        rescue_from StandardError, with: :standard_error
      end
    end

    private

    def standard_error(_e)
      flash[:danger] = "Oops! #{_e}"
      redirect_to list_posts_path
    end
  end
end
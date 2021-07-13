Rails.application.routes.draw do
  root 'posts#index'

  resources :posts do 
    collection do 
      get 'list'
      get 'all'
    end
  end

  # unchanged content 
  get 'about', to: 'statics#about'
end


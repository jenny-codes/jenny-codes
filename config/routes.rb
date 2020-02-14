Rails.application.routes.draw do
  root 'posts#index'

  resources :posts do 
    collection do 
      get 'list'
    end
  end

  # unchanged content 
  get 'about', to: 'statics#about'
  get 'resources', to: 'statics#resources'

  # messaging
  get 'contact', to: 'messages#new'
  post 'contact', to: 'messages#create'
end


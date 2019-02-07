Rails.application.routes.draw do
  root 'posts#index'

  resources :posts
  
  scope '/admin' do
    get 'posts/', to: 'posts#list', as: 'posts/list'
    get 'sync/', to: 'posts#synchronize_with_medium', as: 'posts/sync'
    # get 'posts/idea', to: 'posts#idea', as 'posts/idea'
  end

  # unchanged content 
  get 'about', to: 'statics#about'
  get 'resources', to: 'statics#resources'

  # messaging
  get 'contact', to: 'messages#new'
  post 'contact', to: 'messages#create'
end


Rails.application.routes.draw do
  root 'posts#index'

  resources :posts, only: [:index, :show]

  get 'stream', to: 'posts#stream'

  # unchanged content 
  get 'about', to: 'statics#about'
  get 'resources', to: 'statics#resources'
  get 'contact', to: 'statics#contact'
end

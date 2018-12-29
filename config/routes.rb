Rails.application.routes.draw do
  root 'posts#index'

  resources :posts, only: [:index, :show]
  scope '/admin' do
    resources :posts, except: [:index, :show]
  end

  # unchanged content 
  get 'about', to: 'statics#about'
  get 'resources', to: 'statics#resources'
  get 'contact', to: 'statics#contact'
end

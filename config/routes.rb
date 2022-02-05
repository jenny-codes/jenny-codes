# frozen_string_literal: true

Rails.application.routes.draw do
  root 'statics#about'

  resources :posts do
    collection do
      get 'list'
      get 'all'
    end
  end

  get 'about',     to: 'statics#about'
  get 'talks', to: 'statics#talks'

  get 'limuy', to: 'statics#limuy'
  get 'chloe', to: 'statics#chloe'
end

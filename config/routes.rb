Rails.application.routes.draw do
  root 'statics#about'

  resources :posts do
    collection do
      get 'list'
      get 'all'
    end
  end

  get 'about',     to: 'statics#about'
  get 'speakings', to: 'statics#speakings'

  get 'limuy', to: 'statics#limuy'
  get 'chloe', to: 'statics#chloe'
end

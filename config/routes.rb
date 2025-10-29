# typed: false
# frozen_string_literal: true

Rails.application.routes.draw do
  root "statics#about"

  resources :posts, only: %i[index show] do
    collection do
      get "list"
      get "all"
    end
  end

  get "about",     to: "statics#about"
  get "talks", to: "statics#talks"

  get "limuy", to: "statics#limuy"
  get "chloe", to: "statics#chloe"

  get "advent", to: "advent#index"
  post "advent/check_in", to: "advent#check_in"
end

# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.2.0'

gem 'actionpack', '~> 7.0.4'
gem 'actionview', '~> 7.0.4'
gem 'activesupport', '~> 7.0.4'
gem 'railties', '~> 7.0.4'
# gem "sprockets-rails"

# Use Puma as the app server
gem 'puma', '~> 5.0'
# Use SCSS for stylesheets
gem 'sass-rails', '~> 5.0'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'
# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
gem 'turbolinks', '~> 5'
# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.1.0', require: false

# Allow multiple connections to Memcached server
gem 'connection_pool'

gem 'tzinfo-data'

gem 'slim'
gem 'slim-rails'

gem 'bootstrap', '>= 4.3.1'
gem 'jquery-rails'

# authentication
gem 'figaro'

# Markdown to HTML converter
gem 'redcarpet'

group :test, :development do
  gem 'rubocop'
  gem 'ruby-lsp'
  gem 'sorbet'
  gem 'sorbet-runtime'
  gem 'tapioca', require: false
end

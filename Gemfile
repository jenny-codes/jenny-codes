# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.3.0"

gem "actionpack", "~> 7.0.4"
gem "actionview", "~> 7.0.4"
gem "activesupport", "~> 7.0.7"
gem "railties", "~> 7.0.4"

# Use Puma as the app server
gem "puma", "~> 6.0"
# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", ">= 1.1.0", require: false

gem "tzinfo-data"

gem "slim"
gem "slim-rails"

gem "bootstrap", ">= 4.3.1"
gem "jquery-rails"

# Markdown to HTML converter
gem "redcarpet"

gem "sorbet-static-and-runtime", "~> 0.5.10658"

group :test, :development do
  gem "ruby-lsp"
  gem "tapioca", require: false

  gem "rubocop", "~> 1.45"
  gem "rubocop-shopify", "~> 2.12", require: false
  gem "rubocop-minitest", "~> 0.27.0", require: false
  gem "rubocop-sorbet", "~> 0.7", require: false
end

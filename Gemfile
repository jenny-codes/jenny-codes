# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.3.4"

gem "actionpack", "~> 8.0"
gem "actionview", "~> 8.0"
gem "activesupport", "~> 8.0"
gem "railties", "~> 8.0"

# Use Puma as the app server
gem "puma", "~> 6.0"
# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", ">= 1.1.0", require: false

gem "tzinfo-data"

gem "slim"
gem "slim-rails"

gem "propshaft"
gem "cssbundling-rails"
gem "jsbundling-rails"

# Markdown to HTML converter
gem "redcarpet"

gem "sorbet-static-and-runtime", "~> 0.6.0", ">= 0.6.12665"

group :test, :development do
  gem "ruby-lsp"
  gem "tapioca", require: false

  gem "rubocop", "~> 1.45"
  gem "rubocop-shopify", "~> 2.12", require: false
  gem "rubocop-minitest", "~> 0.27.0", require: false
  gem "rubocop-sorbet", "~> 0.7", require: false
end

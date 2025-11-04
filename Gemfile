# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.3.4"

gem "actionmailer", "~> 8.0"
gem "actionpack", "~> 8.0"
gem "actionview", "~> 8.0"
gem "activerecord", "~> 8.0"
gem "activesupport", "~> 8.0"
gem "railties", "~> 8.0"

# Use Puma as the app server
gem "puma", "~> 6.0"
# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", ">= 1.1.0", require: false

gem "tzinfo-data"

gem "slim"
gem "slim-rails"

gem "cssbundling-rails"
gem "jsbundling-rails"
gem "propshaft"

gem "mailgun-ruby", "~> 1.4"
gem "pg"

gem "sorbet-static-and-runtime"

group :test, :development do
  gem "rubocop"
  gem "rubocop-minitest", "~> 0.27.0"
  gem "rubocop-rails"
  gem "rubocop-sorbet", "~> 0.7"
  gem "ruby-lsp", require: false
  gem "tapioca", require: false
end

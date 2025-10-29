# frozen_string_literal: true

# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative "config/application"

Rails.application.load_tasks

Rake::Task[:test].clear if Rake::Task.task_defined?(:test)

task default: :check

desc "Run tests and formatting in parallel"
multitask check: %i[test_rails test_js format]

desc "Run Rails and JS tests"
task test: %i[test_rails test_js]

desc "Run Rubocop with autofix"
task :format do
  sh "rubocop", "-A"
end

desc "Run Rails test suite"
task :test_rails do
  sh "bin/rails", "test"
end

desc "Run Playwright test suite"
task :test_js do
  sh "npm", "test"
end

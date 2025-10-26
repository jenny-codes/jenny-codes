require_relative "boot"

require "rails"
# Pick the frameworks you want:
# require "active_job/railtie"
# require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
# require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Jennycodes
  class Application < Rails::Application
    config.load_defaults 8.1

    config.time_zone = "Eastern Time (US & Canada)"
    config.autoload_lib(ignore: %w[assets tasks])
  end
end

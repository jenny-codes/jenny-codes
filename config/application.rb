# typed: false
# frozen_string_literal: true

require_relative "boot"

[
  "rails",
  "action_controller/railtie",
  "action_view/railtie",
  "rails/test_unit/railtie",
].each { |railtie| require railtie }

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Jennycodes
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults(7.0)

    config.time_zone = "Taipei"
    config.autoload_paths << Rails.root.join("lib")
    config.eager_load_paths << Rails.root.join("lib")
    config.assets.paths << Rails.root.join("vendor", "assets", "fonts")
    config.assets.precompile += [".jpeg", ".jpg", ".ttc"]
  end
end

ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  def assert_db_queries(expected_hits, &block)
    queries = []

    counter_f = ->(_name, _started, _finished, _unique_id, payload) do
      unless payload[:name].in? %w[CACHE SCHEMA]
        queries << payload[:sql]
      end
    end

    ActiveSupport::Notifications.subscribed(counter_f, 'sql.active_record', &block)

    actual_queries = "Queries performed:\n#{queries.join("\n")}"

    assert_equal expected_hits, queries.count, actual_queries
  end

  def assert_cache_queries(expected_hits, &block)
    queries = []

    counter_f = ->(_name, _started, _finished, _unique_id, payload) do
      if payload[:hit]
        queries << payload[:key]
      end
    end

    ActiveSupport::Notifications.subscribed(counter_f, 'cache_read.active_support', &block)

    actual_queries = "Queries performed:\n#{queries.join("\n")}"

    assert_equal expected_hits, queries.count, actual_queries
  end
end

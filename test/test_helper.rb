# typed: false
# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    def assert_cache_queries(expected_hits, &block)
      queries = []

      counter_f = lambda do |_name, _started, _finished, _unique_id, payload|
        # Count all cache reads, not just hits
        queries << payload[:key]
      end

      ActiveSupport::Notifications.subscribed(counter_f, "cache_read.active_support", &block)

      actual_queries = "Queries performed:\n#{queries.join("\n")}"

      assert_equal(expected_hits, queries.count, actual_queries)
    end
  end
end

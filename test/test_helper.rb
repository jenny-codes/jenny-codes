# typed: false
# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "action_mailer/test_helper"
require "fileutils"
require Rails.root.join("test", "support", "temp_file_store")

test_store_path = Rails.root.join("tmp", "advent_store.test.yml")
FileUtils.rm_f(test_store_path)
ENV["ADVENT_CALENDAR_FILE_PATH"] = test_store_path.to_s
Adapter::AdventCalendar::Store.use!(
  Adapter::AdventCalendar::Store::TempFileStore.new(path: test_store_path)
)

module ActiveSupport
  class TestCase
    include ActionMailer::TestHelper

    setup do
      Adapter::AdventCalendar::Store.instance.reset!(calendar_days: {}, vouchers: [], puzzle_attempts: [])
    end

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

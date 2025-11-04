# typed: false
# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "action_mailer/test_helper"
require "fileutils"

ActiveRecord::Migration.maintain_test_schema!

ENV["ADVENT_PUZZLE_ANSWERS_PATH"] ||= Rails.root.join("tmp", "test_advent_puzzle_answers.yml").to_s
FileUtils.mkdir_p(File.dirname(ENV.fetch("ADVENT_PUZZLE_ANSWERS_PATH")))
File.write(ENV.fetch("ADVENT_PUZZLE_ANSWERS_PATH"), "{}\n") unless File.exist?(ENV.fetch("ADVENT_PUZZLE_ANSWERS_PATH"))
Adapter::AdventCalendar.reload_puzzle_answers!

module ActiveSupport
  class TestCase
    include ActionMailer::TestHelper

    setup do
      CalendarDay.delete_all
      Voucher.delete_all
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

# typed: false
# frozen_string_literal: true

require "test_helper"

module Adapter
  module AdventCalendar
    class MessageTest < ActiveSupport::TestCase
      def test_submit_trims_and_appends_message
        store = Minitest::Mock.new
        store.expect(:append_message, nil) do |payload|
          assert_equal "hello there", payload[:message]
          assert_kind_of String, payload[:timestamp]
          true
        end

        Message.submit!("  hello there  ", store: store)

        store.verify
      end
    end
  end
end

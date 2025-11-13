# typed: true
# frozen_string_literal: true

module Adapter
  module AdventCalendar
    class Message
      class SubmissionError < StandardError; end

      def self.submit!(content, store: Store.instance)
        message = content.to_s.strip
        store.append_message(
          timestamp: current_timestamp,
          message: message
        )
      rescue StandardError => e
        raise SubmissionError, e.message if e.is_a?(SubmissionError)

        raise SubmissionError, "Unable to record message"
      end

      def self.current_timestamp
        (Time.zone ? Time.zone.now : Time.now).iso8601
      end
      private_class_method :current_timestamp
    end
  end
end

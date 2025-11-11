# typed: true
# frozen_string_literal: true

require_relative "advent_calendar/store"
require_relative "advent_calendar/check_in"
require_relative "advent_calendar/prompt"
require_relative "advent_calendar/reward"

module Adapter
  module AdventCalendar
    END_DATE = CheckIn::END_DATE
    NoEligibleDrawsError = Class.new(StandardError)
    VoucherNotFoundError = Class.new(StandardError)
    VoucherAlreadyRedeemedError = Class.new(StandardError)
    VoucherNotRedeemableError = Class.new(StandardError)

    module_function

    def store
      Store.instance
    end
  end
end

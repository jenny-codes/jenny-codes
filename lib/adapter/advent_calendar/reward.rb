# typed: true
# frozen_string_literal: true

require "date"
require "time"

module Adapter
  module AdventCalendar
    class Reward
      VOUCHER_MILESTONES = [3, 13, 23, 33, 43, 53, 63, 73, 83, 94].freeze

      VoucherPayload = Data.define(:id, :title, :details, :awarded_at, :redeemable_at, :redeemed_at) do
        def redeemed?
          redeemed_at.present? && !redeemed_at.to_s.strip.empty?
        end

        def redeemable_on
          return nil if redeemable_at.blank?

          Date.iso8601(redeemable_at.to_s)
        rescue ArgumentError
          nil
        end

        def redeemable?(today = Date.current)
          date = redeemable_on
          return true unless date

          date <= today
        end

        def to_h
          {
            id: id,
            title: title,
            details: details,
            awarded_at: awarded_at,
            redeemable_at: redeemable_at,
            redeemed_at: redeemed_at,
            redeemed: redeemed?,
            redeemable: redeemable?
          }
        end
      end

      attr_reader :day

      def initialize(day:, store:)
        @day = day
        @store = store
      end

      def voucher_milestones
        VOUCHER_MILESTONES
      end

      def draws_unlocked
        VOUCHER_MILESTONES.count { |threshold| total_stars >= threshold }
      end

      def draws_claimed
        store.all_vouchers.count
      end

      def draws_available
        [draws_unlocked - draws_claimed, 0].max
      end

      def can_draw?
        draws_available.positive?
      end

      def draw!(random: nil, catalog: nil)
        raise NoEligibleDrawsError, "No draw unlocked yet" unless can_draw?

        rng = random || Random.new
        pool = Array(catalog || voucher_catalog)
        prize = weighted_prize(pool, rng)

        record = store.append_voucher(
          title: prize.fetch(:title),
          details: prize.fetch(:details),
          awarded_at: current_timestamp.iso8601,
          redeemable_at: prize[:redeemable_at]
        )

        wrap_voucher(record)
      end

      def redeem!(voucher_id)
        record = find_voucher_record(voucher_id)
        voucher = wrap_voucher(record)

        raise VoucherAlreadyRedeemedError, "Voucher already redeemed" if voucher.redeemed?

        unless voucher.redeemable?
          raise VoucherNotRedeemableError,
                "Voucher not redeemable until #{voucher.redeemable_at || 'a future date'}"
        end

        updated = store.update_voucher(record["id"], redeemed_at: current_timestamp.iso8601)
        wrap_voucher(updated)
      end

      def next_milestone
        VOUCHER_MILESTONES.find { |threshold| threshold > total_stars }
      end

      def stars_until_next_milestone
        threshold = next_milestone
        return nil unless threshold

        [threshold - total_stars, 0].max
      end

      def total_stars
        store.total_stars
      end

      def vouchers
        store.all_vouchers.map { |record| wrap_voucher(record).to_h }
      end

      def find_voucher_record(identifier)
        store.find_voucher(identifier.to_s) || raise(VoucherNotFoundError, "Voucher not found")
      end

      def voucher_catalog
        store.voucher_options.map do |item|
          {
            title: item["title"].to_s,
            details: item["details"].to_s,
            chance: item["chance"].to_i,
            redeemable_at: item["redeemable_at"].presence
          }
        end
      end

      private

      attr_reader :store

      def wrap_voucher(record)
        VoucherPayload.new(
          format_voucher_identifier(record["id"]),
          record["title"],
          record["details"],
          format_time(record["awarded_at"]),
          record["redeemable_at"],
          format_time(record["redeemed_at"])
        )
      end

      def weighted_prize(pool, rng)
        raise "Voucher catalogue is empty" if pool.empty?

        total_chance = pool.sum { |item| item[:chance].to_i }
        raise "Voucher chances must sum to 100" unless total_chance == 100

        ticket = rng.rand(total_chance)
        accumulator = 0

        pool.each do |item|
          accumulator += item[:chance].to_i
          return item if ticket < accumulator
        end

        pool.last
      end

      def format_voucher_identifier(id)
        return id if id.to_s.start_with?("voucher-")

        format("voucher-%04d", id.to_i)
      end

      def format_time(value)
        case value
        when Time, DateTime
          value.iso8601
        when String
          value
        else
          value&.to_s
        end
      end

      def current_timestamp
        (Time.zone ? Time.zone.now : Time.now)
      end
    end
  end
end

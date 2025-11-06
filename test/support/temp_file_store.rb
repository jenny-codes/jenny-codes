# typed: false
# frozen_string_literal: true

require "yaml"
require "fileutils"
require "pathname"

module Adapter
  class AdventCalendar
    module Store
      class TempFileStore
        SAMPLE_VOUCHER_OPTIONS = [
          { "title" => "Test Treat", "details" => "Redeemable for one delightful surprise", "chance" => 100 }
        ].freeze

        DEFAULT_PAYLOAD = {
          "calendar_days" => {},
          "vouchers" => [],
          "voucher_options" => SAMPLE_VOUCHER_OPTIONS
        }.freeze

        def initialize(path:)
          @path = Pathname.new(path)
          ensure_file!
          @lock = Mutex.new
        end

        def reset!(calendar_days:, vouchers: [])
          current = read
          write(
            "calendar_days" => calendar_days.transform_values do |attrs|
              {
                "stars" => attrs.fetch("stars", attrs[:stars] || 0).to_i,
                "puzzle_answer" => attrs.fetch("puzzle_answer", attrs[:puzzle_answer])
              }
            end,
            "vouchers" => Array(vouchers).map { |attrs| normalize_voucher(attrs) },
            "voucher_options" => current["voucher_options"]
          )
        end

        def fetch_day(day)
          data = read
          record = data["calendar_days"][day.to_s]
          record&.dup
        end

        def write_day(day:, stars:, puzzle_answer: nil)
          modify do |data|
            data["calendar_days"][day.to_s] = {
              "stars" => stars.to_i,
              "puzzle_answer" => puzzle_answer
            }
          end
          fetch_day(day)
        end

        def all_days
          read["calendar_days"].values.map(&:dup)
        end

        def append_voucher(title:, details:, awarded_at:)
          new_record = nil
          modify do |data|
            seq = next_sequence(data)
            new_record = {
              "id" => format("voucher-%04d", seq),
              "title" => title.to_s,
              "details" => details.to_s,
              "awarded_at" => awarded_at,
              "redeemed_at" => nil
            }
            data["vouchers"] << new_record
          end
          new_record.dup
        end

        def update_voucher(id, redeemed_at:)
          record = nil
          modify do |data|
            entry = data["vouchers"].find { |v| v["id"] == id }
            next unless entry

            entry["redeemed_at"] = redeemed_at
            record = entry.dup
          end
          record
        end

        def all_vouchers
          read["vouchers"].map(&:dup)
        end

        def find_voucher(id)
          read["vouchers"].find { |entry| entry["id"] == id }&.dup
        end

        def voucher_options
          read["voucher_options"].map(&:dup)
        end

        private

        def ensure_file!
          FileUtils.mkdir_p(@path.dirname)
          return if @path.exist?

          File.write(@path, YAML.dump(DEFAULT_PAYLOAD))
        end

        def read
          payload = YAML.safe_load(@path.read, permitted_classes: [Date], symbolize_names: false) || {}
          normalize_payload(payload)
        end

        def normalize_payload(payload)
          normalized = DEFAULT_PAYLOAD.merge(payload)
          normalized["calendar_days"] = (normalized["calendar_days"] || {}).transform_values do |attrs|
            {
              "stars" => attrs.fetch("stars", attrs[:stars] || 0).to_i,
              "puzzle_answer" => attrs.fetch("puzzle_answer", attrs[:puzzle_answer])
            }
          end
          normalized["vouchers"] = Array(normalized["vouchers"]).map { |attrs| normalize_voucher(attrs) }
          normalized["voucher_options"] = Array(normalized["voucher_options"]).map do |attrs|
            {
              "title" => attrs.fetch("title", attrs[:title]).to_s,
              "details" => attrs.fetch("details", attrs[:details]).to_s,
              "chance" => attrs.fetch("chance", attrs[:chance] || 0).to_i
            }
          end
          normalized
        end

        def write(payload)
          @lock.synchronize do
            File.write(@path, YAML.dump(payload))
          end
        end

        def modify
          @lock.synchronize do
            current = read
            yield current
            File.write(@path, YAML.dump(current))
          end
        end

        def normalize_voucher(attrs)
          {
            "id" => attrs.fetch("id", attrs[:id])&.to_s,
            "title" => attrs.fetch("title", attrs[:title]).to_s,
            "details" => attrs.fetch("details", attrs[:details]).to_s,
            "awarded_at" => attrs.fetch("awarded_at", attrs[:awarded_at])&.to_s,
            "redeemed_at" => attrs.fetch("redeemed_at", attrs[:redeemed_at])&.to_s
          }
        end

        def next_sequence(data)
          current_max = data["vouchers"].map { |entry| entry["id"].to_s[/voucher-(\d+)/, 1].to_i }.max || 0
          current_max + 1
        end
      end
    end
  end
end

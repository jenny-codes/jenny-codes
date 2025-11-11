# typed: false
# frozen_string_literal: true

require "yaml"
require "fileutils"
require "pathname"

module Adapter
  module AdventCalendar
    module Store
      class TempFileStore
        SAMPLE_VOUCHER_OPTIONS = [
          {
            "title" => "Test Treat",
            "details" => "Redeemable for one delightful surprise",
            "chance" => 100,
            "redeemable_at" => Date.current.iso8601
          }
        ].freeze

        DEFAULT_PAYLOAD = {
          "calendar_days" => {},
          "vouchers" => [],
          "voucher_options" => SAMPLE_VOUCHER_OPTIONS,
          "prompts" => {},
          "puzzle_attempts" => []
        }.freeze

        def initialize(path:)
          @path = Pathname.new(path)
          ensure_file!
          @lock = Mutex.new
        end

        def reset!(calendar_days:, vouchers: [], voucher_options: nil, prompts: nil, puzzle_attempts: nil)
          current = read
          payload = {
            "calendar_days" => normalize_calendar_days(calendar_days),
            "vouchers" => normalize_vouchers(vouchers),
            "voucher_options" => normalize_options(voucher_options) || current["voucher_options"],
            "prompts" => normalize_prompts_payload(prompts) || current["prompts"],
            "puzzle_attempts" => normalize_attempts(puzzle_attempts) || current["puzzle_attempts"]
          }

          write(payload)
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
          read["calendar_days"].map do |day, attrs|
            { "day" => day }.merge(attrs.dup)
          end
        end

        def total_stars
          read["calendar_days"].values.sum { |attrs| attrs["stars"].to_i }
        end

        def append_voucher(title:, details:, awarded_at:, redeemable_at:)
          new_record = nil
          modify do |data|
            seq = next_sequence(data)
            new_record = {
              "id" => format("voucher-%04d", seq),
              "title" => title.to_s,
              "details" => details.to_s,
              "awarded_at" => awarded_at,
              "redeemable_at" => redeemable_at,
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

        def prompt_for(day)
          read["prompts"][day.to_s]&.dup
        end

        def all_prompts
          read["prompts"].values.map(&:dup)
        end

        def append_puzzle_attempt(day:, timestamp:, attempt:)
          entry = nil
          modify do |data|
            entry = {
              "day" => day.to_s,
              "timestamp" => timestamp.to_s,
              "attempt" => attempt.to_s
            }
            data["puzzle_attempts"] << entry
          end
          entry.dup
        end

        def puzzle_attempts
          read["puzzle_attempts"].map(&:dup)
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
          normalized["calendar_days"] = normalize_calendar_days(normalized["calendar_days"] || {})
          normalized["vouchers"] = normalize_vouchers(normalized["vouchers"])
          normalized["voucher_options"] = normalize_options(normalized["voucher_options"])
          normalized["prompts"] = normalize_prompts_payload(normalized["prompts"]) || {}
          normalized["puzzle_attempts"] = normalize_attempts(normalized["puzzle_attempts"]) || []
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
            "redeemable_at" => attrs.fetch("redeemable_at", attrs[:redeemable_at])&.to_s,
            "redeemed_at" => attrs.fetch("redeemed_at", attrs[:redeemed_at])&.to_s
          }
        end

        def normalize_option(attrs)
          {
            "title" => attrs.fetch("title", attrs[:title]).to_s,
            "details" => attrs.fetch("details", attrs[:details]).to_s,
            "chance" => attrs.fetch("chance", attrs[:chance] || 0).to_i,
            "redeemable_at" => attrs.fetch("redeemable_at", attrs[:redeemable_at])&.to_s
          }
        end

        def normalize_prompt(attrs)
          attrs.transform_keys(&:to_s).transform_values { |value| value&.to_s }
        end

        def normalize_calendar_days(calendar_days)
          calendar_days.each_with_object({}) do |(day, attrs), memo|
            memo[day.to_s] = {
              "stars" => attrs.fetch("stars", attrs[:stars] || 0).to_i,
              "puzzle_answer" => attrs.fetch("puzzle_answer", attrs[:puzzle_answer])
            }
          end
        end

        def normalize_vouchers(vouchers)
          Array(vouchers).map { |attrs| normalize_voucher(attrs) }
        end

        def normalize_options(options)
          return nil unless options

          Array(options).map { |attrs| normalize_option(attrs) }
        end

        def normalize_prompts_payload(prompts)
          return nil unless prompts

          prompts.transform_keys(&:to_s).transform_values { |attrs| normalize_prompt(attrs) }
        end

        def normalize_attempts(records)
          return nil unless records

          Array(records).map do |attrs|
            {
              "day" => attrs.fetch("day", attrs[:day]).to_s,
              "timestamp" => attrs.fetch("timestamp", attrs[:timestamp]).to_s,
              "attempt" => attrs.fetch("attempt", attrs[:attempt]).to_s
            }
          end
        end

        def next_sequence(data)
          current_max = data["vouchers"].map { |entry| entry["id"].to_s[/voucher-(\d+)/, 1].to_i }.max || 0
          current_max + 1
        end
      end
    end
  end
end

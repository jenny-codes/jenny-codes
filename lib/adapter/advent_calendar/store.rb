# typed: false
# frozen_string_literal: true

require "date"
require "stringio"
require "base64"

module Adapter
  module AdventCalendar
    module Store
      class << self
        def instance
          @instance ||= build
        end

        def use!(store)
          @instance = store
        end

        private

        def build
          credentials_key = Base64.decode64(ENV.fetch("GOOGLE_SERVICE_ACCOUNT_KEY"))
          Sheets.new(
            spreadsheet_id: ENV.fetch("ADVENT_CALENDAR_SPREADSHEET_ID"),
            credentials_key: credentials_key
          )
        end
      end

      class Sheets
        CALENDAR_TAB = "calendar_days"
        CALENDAR_HEADER = %w[day stars].freeze

        VOUCHER_TAB = "vouchers"
        VOUCHER_HEADER = %w[id title details awarded_at redeemable_at redeemed_at].freeze

        OPTIONS_RANGE = "voucher_options!A2:D"
        OPTIONS_HEADER = %w[title details chance redeemable_at].freeze

        PROMPTS_TAB = "prompts"
        PROMPTS_RANGE = "#{PROMPTS_TAB}!A1:Z".freeze

        PUZZLE_ATTEMPTS_TAB = "puzzle_attempts"
        PUZZLE_ATTEMPTS_HEADER = %w[day timestamp attempt].freeze

        def initialize(spreadsheet_id:, credentials_key:)
          require "google/apis/sheets_v4"
          require "googleauth"

          @spreadsheet_id = spreadsheet_id
          @service = Google::Apis::SheetsV4::SheetsService.new
          @service.authorization = Google::Auth::ServiceAccountCredentials.make_creds(
            json_key_io: StringIO.new(credentials_key),
            scope: [Google::Apis::SheetsV4::AUTH_SPREADSHEETS]
          )
          ensure_headers!
        end

        def fetch_day(day)
          calendar_rows.find { |row| row["day"] == day.to_s }&.dup
        end

        def write_day(day:, stars:)
          rows = calendar_rows
          index = rows.index { |row| row["day"] == day.to_s }
          record = {
            "day" => day.to_s,
            "stars" => stars.to_i
          }
          if index
            rows[index] = record
          else
            rows << record
          end
          write_calendar_rows(rows)
          record
        end

        def all_days
          calendar_rows.map(&:dup)
        end

        def total_stars
          calendar_rows.sum { |row| row["stars"].to_i }
        end

        def append_voucher(title:, details:, awarded_at:, redeemable_at:)
          id = format("voucher-%04d", next_voucher_sequence)
          row = [id, title.to_s, details.to_s, awarded_at, redeemable_at, nil]
          value_range = Google::Apis::SheetsV4::ValueRange.new(values: [row])
          @service.append_spreadsheet_value(
            @spreadsheet_id,
            voucher_range("A:F"),
            value_range,
            value_input_option: "RAW",
            insert_data_option: "INSERT_ROWS"
          )
          @voucher_rows = nil
          build_voucher_hash(row)
        end

        def update_voucher(id, redeemed_at:)
          rows = voucher_rows
          index = rows.index { |row| row[0] == id }
          return unless index

          rows[index][5] = redeemed_at
          write_voucher_rows(rows)
          build_voucher_hash(rows[index])
        end

        def all_vouchers
          voucher_rows.map { |row| build_voucher_hash(row) }
        end

        def find_voucher(id)
          row = voucher_rows.find { |values| values[0] == id }
          row ? build_voucher_hash(row) : nil
        end

        def voucher_options
          rows = option_rows
          return [] if rows.empty?

          rows.map do |values|
            title, details, chance, redeemable_at = values
            {
              "title" => title.to_s,
              "details" => details.to_s,
              "chance" => chance.to_i,
              "redeemable_at" => redeemable_at.to_s
            }
          end
        end

        def prompt_for(day)
          prompt_rows.find { |row| row["day"] == day.to_s }
        end

        def append_puzzle_attempt(day:, timestamp:, attempt:)
          row = [day.to_s, timestamp.to_s, attempt.to_s]
          value_range = Google::Apis::SheetsV4::ValueRange.new(values: [row])
          @service.append_spreadsheet_value(
            @spreadsheet_id,
            puzzle_attempt_range("A:C"),
            value_range,
            value_input_option: "RAW",
            insert_data_option: "INSERT_ROWS"
          )
          row
        end

        private

        def ensure_headers!
          set_headers(calendar_range("A1:C1"), CALENDAR_HEADER)
          set_headers(voucher_range("A1:F1"), VOUCHER_HEADER)
          set_headers("voucher_options!A1:D1", OPTIONS_HEADER)
          set_headers(puzzle_attempt_range("A1:C1"), PUZZLE_ATTEMPTS_HEADER)
        end

        def set_headers(range, headers)
          value_range = Google::Apis::SheetsV4::ValueRange.new(values: [headers])
          @service.update_spreadsheet_value(
            @spreadsheet_id,
            range,
            value_range,
            value_input_option: "RAW"
          )
        end

        def calendar_rows
          @calendar_rows ||= begin
            response = @service.get_spreadsheet_values(@spreadsheet_id, calendar_range)
            Array(response.values).map do |values|
              day, stars = values
              {
                "day" => day.to_s,
                "stars" => stars.to_i
              }
            end
          end
        end

        def voucher_rows
          @voucher_rows ||= begin
            response = @service.get_spreadsheet_values(@spreadsheet_id, voucher_range)
            Array(response.values).map do |values|
              values.fill(nil, values.length...6)
              values
            end
          end
        end

        def option_rows
          @option_rows ||= begin
            response = @service.get_spreadsheet_values(@spreadsheet_id, OPTIONS_RANGE)
            Array(response.values)
          end
        end

        # No caching prompts so it can always read the latest value
        def prompt_rows
          response = @service.get_spreadsheet_values(@spreadsheet_id, PROMPTS_RANGE)
          rows = Array(response.values)
          return [] if rows.empty?

          header = normalize_header_row(rows.shift)
          rows.map do |values|
            row = {}
            header.each_with_index do |key, index|
              row[key] = values[index]
            end
            row
          end
        end

        def write_calendar_rows(rows)
          values = rows.map do |row|
            [row["day"], row["stars"]]
          end

          if values.empty?
            @service.clear_values(@spreadsheet_id, calendar_range, Google::Apis::SheetsV4::ClearValuesRequest.new)
          else
            value_range = Google::Apis::SheetsV4::ValueRange.new(values: values)
            @service.update_spreadsheet_value(
              @spreadsheet_id,
              calendar_range,
              value_range,
              value_input_option: "RAW"
            )
          end

          @calendar_rows = nil
        end

        def write_voucher_rows(rows)
          if rows.empty?
            @service.clear_values(@spreadsheet_id, voucher_range, Google::Apis::SheetsV4::ClearValuesRequest.new)
          else
            value_range = Google::Apis::SheetsV4::ValueRange.new(values: rows)
            @service.update_spreadsheet_value(
              @spreadsheet_id,
              voucher_range,
              value_range,
              value_input_option: "RAW"
            )
          end

          @voucher_rows = nil
        end

        def next_voucher_sequence
          current_max = voucher_rows.map { |row| row[0].to_s[/voucher-(\d+)/, 1].to_i }.max || 0
          current_max + 1
        end

        def build_voucher_hash(row)
          {
            "id" => row[0],
            "title" => row[1],
            "details" => row[2],
            "awarded_at" => row[3],
            "redeemable_at" => row[4],
            "redeemed_at" => row[5]
          }
        end

        def calendar_tab
          Rails.env.development? ? "#{CALENDAR_TAB}_dev" : CALENDAR_TAB
        end

        def voucher_tab
          Rails.env.development? ? "#{VOUCHER_TAB}_dev" : VOUCHER_TAB
        end

        def puzzle_attempt_tab
          Rails.env.development? ? "#{PUZZLE_ATTEMPTS_TAB}_dev" : PUZZLE_ATTEMPTS_TAB
        end

        def calendar_range(segment = "A2:B")
          "#{calendar_tab}!#{segment}"
        end

        def voucher_range(segment = "A2:F")
          "#{voucher_tab}!#{segment}"
        end

        def puzzle_attempt_range(segment = "A:C")
          "#{puzzle_attempt_tab}!#{segment}"
        end

        def normalize_header_row(values)
          values.map do |value|
            value.to_s.strip.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_+|_+\z/, "")
          end
        end
      end
    end
  end
end

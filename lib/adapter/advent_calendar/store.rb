# typed: false
# frozen_string_literal: true

require "date"
require "stringio"
require "base64"

module Adapter
  class AdventCalendar
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
            spreadsheet_id: ENV.fetch(
              "ADVENT_CALENDAR_SPREADSHEET_ID",
              "1HON1eX9ondKVsmKv1OLUs85vNjmqna5AC8lBANWIg4I"
            ),
            credentials_key: credentials_key
          )
        end
      end

      class Sheets
        CALENDAR_TAB = "calendar_days"
        CALENDAR_HEADER = %w[day stars puzzle_answer].freeze
        VOUCHER_TAB = "vouchers"
        VOUCHER_HEADER = %w[id title details awarded_at redeemed_at].freeze
        OPTIONS_RANGE = "voucher_options!A2:C"
        OPTIONS_HEADER = %w[title details chance].freeze

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

        def write_day(day:, stars:, puzzle_answer: nil)
          rows = calendar_rows
          index = rows.index { |row| row["day"] == day.to_s }
          record = {
            "day" => day.to_s,
            "stars" => stars.to_i,
            "puzzle_answer" => puzzle_answer
          }
          if index
            rows[index] = record
          else
            rows << record
          end
          write_calendar_rows(rows)
          record.dup
        end

        def all_days
          calendar_rows.map(&:dup)
        end

        def append_voucher(title:, details:, awarded_at:)
          id = format("voucher-%04d", next_voucher_sequence)
          row = [id, title.to_s, details.to_s, awarded_at, nil]
          value_range = Google::Apis::SheetsV4::ValueRange.new(values: [row])
          @service.append_spreadsheet_value(
            @spreadsheet_id,
            voucher_range("A:E"),
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

          rows[index][4] = redeemed_at
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
            title, details, chance = values
            {
              "title" => title.to_s,
              "details" => details.to_s,
              "chance" => chance.to_i
            }
          end
        end

        private

        def ensure_headers!
          set_headers(calendar_range("A1:C1"), CALENDAR_HEADER)
          set_headers(voucher_range("A1:E1"), VOUCHER_HEADER)
          set_headers("voucher_options!A1:C1", OPTIONS_HEADER)
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
              day, stars, puzzle_answer = values
              {
                "day" => day.to_s,
                "stars" => stars.to_i,
                "puzzle_answer" => puzzle_answer
              }
            end
          end
        end

        def voucher_rows
          @voucher_rows ||= begin
            response = @service.get_spreadsheet_values(@spreadsheet_id, voucher_range)
            Array(response.values).map do |values|
              values.fill(nil, values.length...5)
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

        def write_calendar_rows(rows)
          values = rows.map do |row|
            [row["day"], row["stars"], row["puzzle_answer"]]
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
            "redeemed_at" => row[4]
          }
        end

        def calendar_tab
          Rails.env.development? ? "#{CALENDAR_TAB}_dev" : CALENDAR_TAB
        end

        def voucher_tab
          Rails.env.development? ? "#{VOUCHER_TAB}_dev" : VOUCHER_TAB
        end

        def calendar_range(segment = "A2:C")
          "#{calendar_tab}!#{segment}"
        end

        def voucher_range(segment = "A2:E")
          "#{voucher_tab}!#{segment}"
        end
      end
    end
  end
end

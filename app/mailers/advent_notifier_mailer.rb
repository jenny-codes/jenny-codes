# typed: false
# frozen_string_literal: true

class AdventNotifierMailer < ApplicationMailer
  default from: "advent@jenny.sh"
  RECIPIENT = "jinghua.shih@gmail.com"

  def check_in(day:)
    @day = normalize_day(day)
    mail(to: RECIPIENT, subject: "[Advent Calendar] Checked in for #{@day}")
  end

  def puzzle_attempt(day:, attempt:, solved: false)
    @day = normalize_day(day)
    @attempt = attempt
    @solved = solved

    mail(to: RECIPIENT, subject: "[Advent Calendar] Puzzle attempt made for #{@day}")
  end

  def voucher_drawn(day:, title:, details:)
    @day = normalize_day(day)
    @title = title
    @details = details

    mail(to: RECIPIENT, subject: "[Advent Calendar] Voucher drawn!")
  end

  private

  def normalize_day(day)
    return day.iso8601 if day.respond_to?(:iso8601)

    day.to_s
  end
end

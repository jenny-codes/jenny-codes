# typed: false
# frozen_string_literal: true

module ApplicationHelper
  def flash_messages(_opts = {})
    flash.each do |msg_type, msg|
      concat(
        content_tag(:div, msg, class: "alert alert-#{msg_type} alert-dismissable fade-in") do
          concat(content_tag(:button, "x", class: "close", data: { dismiss: "alert" }))
          concat(msg.html_safe)
        end
      )
    end
    nil
  end

  def advent_voucher_redeemable_label(voucher)
    raw_date = voucher[:redeemable_at]
    return if raw_date.blank?

    date = Date.iso8601(raw_date.to_s)
    content_tag(:p, "Redeemable on #{date.strftime('%b %d, %Y')}", class: "advent-voucher-card__status")
  rescue ArgumentError
    nil
  end

  def advent_voucher_redeemed_label(voucher)
    raw_timestamp = voucher[:redeemed_at]
    return "Redeemed" if raw_timestamp.blank?

    date = Date.parse(raw_timestamp.to_s)
    "Redeemed on #{date.strftime('%b %d, %Y')}"
  rescue ArgumentError
    "Redeemed"
  end
end

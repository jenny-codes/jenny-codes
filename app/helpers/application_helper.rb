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
end

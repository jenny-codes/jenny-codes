# typed: false
# frozen_string_literal: true

module Caching
  def cache(name, **args, &block)
    key = "#{name}|#{args.map { |k, v| "#{k}:#{v}" }.join('|')}"
    Rails.cache.fetch(
      key,
      expires_in: 7.days,
      race_condition_ttl: 10.seconds
    ) do
      block.call
    end
  end
end

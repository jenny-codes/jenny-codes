# frozen_string_literal: true

require "test_helper"
require "playwright_helper"

class AdventPlaywrightTest < ActiveSupport::TestCase
  include PlaywrightHelper

  def test_advent_console_behaviour
    with_playwright_server do
      system("npx", "playwright", "test", "tests/playwright/advent.spec.ts", exception: true)
    end
  end
end

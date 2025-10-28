# frozen_string_literal: true

require "application_system_test_case"

class AdventPlaywrightTest < ApplicationSystemTestCase
  driven_by :selenium, using: :chrome_headless

  setup do
    @server_thread = Thread.new do
      system("bin/rails test:prepare", exception: true)
      system("bin/rails server -p 3000 --environment test", exception: true)
    end

    wait_for_server
  end

  teardown do
    Thread.kill(@server_thread) if @server_thread&.alive?
  end

  def wait_for_server
    require "net/http"

    tries = 0
    loop do
      tries += 1
      begin
        Net::HTTP.start("localhost", 3000) { |_http| break }
      rescue Errno::ECONNREFUSED
        raise "Server never booted" if tries > 50

        sleep 0.2
      end
    end
  end

  test "playwright smoke tests" do
    system("npx", "playwright", "test", "tests/playwright/advent.spec.ts", exception: true)
  end
end

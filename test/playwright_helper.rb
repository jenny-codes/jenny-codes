# frozen_string_literal: true

require "net/http"
require "open3"

module PlaywrightHelper
  module_function

  def with_playwright_server
    port = ENV.fetch("PLAYWRIGHT_SERVER_PORT", "3101")
    server_cmd = ["bin/rails", "server", "-p", port, "--environment", "test"]
    server = spawn(*server_cmd, out: File::NULL, err: File::NULL)
    wait_for_server(Integer(port))
    ENV["PLAYWRIGHT_BASE_URL"] = "http://localhost:#{port}"

    yield
  ensure
    Process.kill("TERM", server) if server
    Process.wait(server) if server
    ENV.delete("PLAYWRIGHT_BASE_URL")
  end

  def wait_for_server(port)
    100.times do
      begin
        Net::HTTP.start("localhost", port) { |_http| return }
      rescue Errno::ECONNREFUSED
        sleep 0.1
      end
    end
    raise "Server on port #{port} was not ready in time"
  end
end

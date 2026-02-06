# frozen_string_literal: true

require "test_helper"

class RackMiddlewareTest < Minitest::Test
  BASE_URL = "http://localhost:8080"
  API_KEY  = "test-api-key"

  def setup
    WebMock.reset!
    CmdLog.reset!

    # Stub both single-log and batch endpoints so the middleware's log calls succeed
    stub_request(:post, "#{BASE_URL}/api/v1/logs")
      .to_return(status: 201, body: '{"id":1}', headers: { "Content-Type" => "application/json" })
    stub_request(:post, "#{BASE_URL}/api/v1/logs/batch")
      .to_return(status: 201, body: '{"accepted":1}', headers: { "Content-Type" => "application/json" })

    CmdLog.configure do |c|
      c.api_url = BASE_URL
      c.api_key = API_KEY
      c.enable_batching = false
    end
  end

  def teardown
    CmdLog.reset!
  end

  def build_env(path: "/users", method: "GET", request_id: nil)
    env = {
      "PATH_INFO" => path,
      "REQUEST_METHOD" => method,
      "QUERY_STRING" => "",
      "REMOTE_ADDR" => "127.0.0.1",
      "HTTP_USER_AGENT" => "TestAgent/1.0"
    }
    env["HTTP_X_REQUEST_ID"] = request_id if request_id
    env
  end

  def success_app
    ->(env) { [200, { "Content-Type" => "text/html" }, ["OK"]] }
  end

  def error_app
    ->(env) { raise RuntimeError, "boom" }
  end

  # --- Normal request ---

  def test_logs_request_and_response
    middleware = CmdLog::Middleware::RackMiddleware.new(success_app)

    status, = middleware.call(build_env)

    assert_equal 200, status
    # Two POST requests: one for the request log, one for the response log
    assert_requested(:post, "#{BASE_URL}/api/v1/logs", times: 2)
  end

  # --- Error handling ---

  def test_logs_error_and_reraises
    middleware = CmdLog::Middleware::RackMiddleware.new(error_app)

    assert_raises(RuntimeError) do
      middleware.call(build_env)
    end

    # Request log + error log = 2 calls
    assert_requested(:post, "#{BASE_URL}/api/v1/logs", times: 2)
  end

  # --- Skip paths ---

  def test_skips_asset_paths
    middleware = CmdLog::Middleware::RackMiddleware.new(success_app)

    status, = middleware.call(build_env(path: "/assets/app.js"))

    assert_equal 200, status
    assert_not_requested(:post, "#{BASE_URL}/api/v1/logs")
  end

  def test_skips_health_path
    middleware = CmdLog::Middleware::RackMiddleware.new(success_app)

    status, = middleware.call(build_env(path: "/health"))

    assert_equal 200, status
    assert_not_requested(:post, "#{BASE_URL}/api/v1/logs")
  end

  def test_skips_favicon
    middleware = CmdLog::Middleware::RackMiddleware.new(success_app)

    status, = middleware.call(build_env(path: "/favicon.ico"))

    assert_equal 200, status
    assert_not_requested(:post, "#{BASE_URL}/api/v1/logs")
  end

  def test_custom_skip_paths
    middleware = CmdLog::Middleware::RackMiddleware.new(success_app, skip_paths: ["/internal"])

    status, = middleware.call(build_env(path: "/internal/status"))

    assert_equal 200, status
    assert_not_requested(:post, "#{BASE_URL}/api/v1/logs")
  end

  # --- Request ID ---

  def test_uses_existing_request_id
    captured_bodies = []
    stub_request(:post, "#{BASE_URL}/api/v1/logs")
      .with { |req| captured_bodies << JSON.parse(req.body); true }
      .to_return(status: 201, body: '{"id":1}', headers: { "Content-Type" => "application/json" })

    middleware = CmdLog::Middleware::RackMiddleware.new(success_app)
    middleware.call(build_env(request_id: "my-req-id"))

    # Both log entries should reference the same request_id
    request_ids = captured_bodies.map { |b| b.dig("log", "metadata", "request_id") }
    assert_equal %w[my-req-id my-req-id], request_ids
  end

  def test_generates_uuid_when_no_request_id
    captured_bodies = []
    stub_request(:post, "#{BASE_URL}/api/v1/logs")
      .with { |req| captured_bodies << JSON.parse(req.body); true }
      .to_return(status: 201, body: '{"id":1}', headers: { "Content-Type" => "application/json" })

    middleware = CmdLog::Middleware::RackMiddleware.new(success_app)
    middleware.call(build_env)

    request_ids = captured_bodies.map { |b| b.dig("log", "metadata", "request_id") }
    assert_equal 2, request_ids.length
    # Both should be the same generated UUID
    assert_equal request_ids[0], request_ids[1]
    # Should look like a UUID
    assert_match(/\A[0-9a-f\-]{36}\z/, request_ids[0])
  end
end

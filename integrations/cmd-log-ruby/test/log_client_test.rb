# frozen_string_literal: true

require "test_helper"

class LogClientTest < Minitest::Test
  BASE_URL = "http://localhost:8080"
  API_KEY  = "test-api-key"

  def setup
    WebMock.reset!
  end

  def new_client(**overrides)
    CmdLog::LogClient.new(
      api_url: overrides.fetch(:api_url, BASE_URL),
      api_key: overrides.fetch(:api_key, API_KEY),
      service: overrides.fetch(:service, "test-service"),
      enable_batching: overrides.fetch(:enable_batching, false),
      max_retries: overrides.fetch(:max_retries, 0),
      retry_delay: overrides.fetch(:retry_delay, 0),
      on_error: overrides.fetch(:on_error, ->(e) {})
    )
  end

  # --- Convenience methods ---

  def test_info_sends_info_level
    stub = stub_request(:post, "#{BASE_URL}/api/v1/logs")
      .with { |req| JSON.parse(req.body).dig("log", "level") == "INFO" }
      .to_return(status: 201, body: '{"id":1}', headers: { "Content-Type" => "application/json" })

    new_client.info("hello")

    assert_requested(stub)
  end

  def test_error_sends_error_level
    stub = stub_request(:post, "#{BASE_URL}/api/v1/logs")
      .with { |req| JSON.parse(req.body).dig("log", "level") == "ERROR" }
      .to_return(status: 201, body: '{"id":1}', headers: { "Content-Type" => "application/json" })

    new_client.error("boom")

    assert_requested(stub)
  end

  def test_debug_sends_debug_level
    stub = stub_request(:post, "#{BASE_URL}/api/v1/logs")
      .with { |req| JSON.parse(req.body).dig("log", "level") == "DEBUG" }
      .to_return(status: 201, body: '{"id":1}', headers: { "Content-Type" => "application/json" })

    new_client.debug("trace")

    assert_requested(stub)
  end

  def test_warn_sends_warn_level
    stub = stub_request(:post, "#{BASE_URL}/api/v1/logs")
      .with { |req| JSON.parse(req.body).dig("log", "level") == "WARN" }
      .to_return(status: 201, body: '{"id":1}', headers: { "Content-Type" => "application/json" })

    new_client.warn("careful")

    assert_requested(stub)
  end

  def test_fatal_sends_fatal_level
    stub = stub_request(:post, "#{BASE_URL}/api/v1/logs")
      .with { |req| JSON.parse(req.body).dig("log", "level") == "FATAL" }
      .to_return(status: 201, body: '{"id":1}', headers: { "Content-Type" => "application/json" })

    new_client.fatal("dead")

    assert_requested(stub)
  end

  # --- Log entry format ---

  def test_log_entry_includes_required_fields
    captured_body = nil
    stub_request(:post, "#{BASE_URL}/api/v1/logs")
      .with { |req| captured_body = JSON.parse(req.body); true }
      .to_return(status: 201, body: '{"id":1}', headers: { "Content-Type" => "application/json" })

    new_client.info("test message", { user_id: 42 })

    log = captured_body["log"]
    assert_equal "test-service", log["service"]
    assert_equal "INFO", log["level"]
    assert_equal "test message", log["message"]
    assert log.key?("timestamp"), "expected timestamp to be present"
    assert_equal({ "user_id" => 42 }, log["metadata"])
  end

  def test_log_entry_omits_empty_metadata
    captured_body = nil
    stub_request(:post, "#{BASE_URL}/api/v1/logs")
      .with { |req| captured_body = JSON.parse(req.body); true }
      .to_return(status: 201, body: '{"id":1}', headers: { "Content-Type" => "application/json" })

    new_client.info("no metadata")

    log = captured_body["log"]
    refute log.key?("metadata"), "expected metadata to be absent for empty hash"
  end

  # --- Batching ---

  def test_batching_queues_and_flushes
    stub = stub_request(:post, "#{BASE_URL}/api/v1/logs/batch")
      .with { |req| JSON.parse(req.body)["logs"].length == 2 }
      .to_return(status: 201, body: '{"accepted":2}', headers: { "Content-Type" => "application/json" })

    client = new_client(enable_batching: true)
    client.info("one")
    client.info("two")
    client.flush

    assert_requested(stub)
    client.destroy
  end

  def test_destroy_flushes_remaining
    stub = stub_request(:post, "#{BASE_URL}/api/v1/logs/batch")
      .to_return(status: 201, body: '{"accepted":1}', headers: { "Content-Type" => "application/json" })

    client = new_client(enable_batching: true)
    client.info("pending")
    client.destroy

    assert_requested(stub)
  end

  # --- Failed logs ---

  def test_failed_logs_tracked_on_error
    stub_request(:post, "#{BASE_URL}/api/v1/logs")
      .to_return(status: 500, body: '{"error":"fail"}', headers: { "Content-Type" => "application/json" })

    client = new_client
    client.info("will fail")

    assert_equal 1, client.failed_logs.length
    assert_equal "will fail", client.failed_logs[0][:message]
  end

  def test_retry_failed_logs_replays
    call_count = 0
    stub_request(:post, "#{BASE_URL}/api/v1/logs")
      .to_return { |_|
        call_count += 1
        if call_count <= 1
          { status: 500, body: '{"error":"fail"}', headers: { "Content-Type" => "application/json" } }
        else
          { status: 201, body: '{"id":1}', headers: { "Content-Type" => "application/json" } }
        end
      }

    client = new_client
    client.info("retry me")

    assert_equal 1, client.failed_logs.length

    client.retry_failed_logs

    assert_equal 0, client.failed_logs.length
  end

  # --- Direct send ---

  def test_send_log_bypasses_batching
    stub = stub_request(:post, "#{BASE_URL}/api/v1/logs")
      .to_return(status: 201, body: '{"id":1}', headers: { "Content-Type" => "application/json" })

    client = new_client(enable_batching: true)
    client.send_log({ timestamp: Time.now.utc.iso8601, service: "x", level: "INFO", message: "direct" })

    assert_requested(stub)
    client.destroy
  end
end

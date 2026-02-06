# frozen_string_literal: true

require "test_helper"

class HttpClientTest < Minitest::Test
  BASE_URL = "http://localhost:8080"
  API_KEY  = "test-api-key"

  def setup
    WebMock.reset!
  end

  def new_client(**overrides)
    CmdLog::HttpClient.new(
      api_url: overrides.fetch(:api_url, BASE_URL),
      api_key: overrides.fetch(:api_key, API_KEY),
      max_retries: overrides.fetch(:max_retries, 0),
      retry_delay: overrides.fetch(:retry_delay, 0)
    )
  end

  # --- Configuration validation ---

  def test_raises_on_nil_api_url
    assert_raises(CmdLog::ConfigurationError) do
      CmdLog::HttpClient.new(api_url: nil, api_key: "key")
    end
  end

  def test_raises_on_empty_api_url
    assert_raises(CmdLog::ConfigurationError) do
      CmdLog::HttpClient.new(api_url: "", api_key: "key")
    end
  end

  def test_raises_on_nil_api_key
    assert_raises(CmdLog::ConfigurationError) do
      CmdLog::HttpClient.new(api_url: BASE_URL, api_key: nil)
    end
  end

  def test_raises_on_empty_api_key
    assert_raises(CmdLog::ConfigurationError) do
      CmdLog::HttpClient.new(api_url: BASE_URL, api_key: "")
    end
  end

  # --- Headers ---

  def test_sends_correct_headers
    stub_request(:get, "#{BASE_URL}/api/v1/test")
      .with(
        headers: {
          "X-API-Key" => API_KEY,
          "Content-Type" => "application/json",
          "Accept" => "application/json",
          "User-Agent" => "cmd_log-ruby/#{CmdLog::VERSION}"
        }
      )
      .to_return(status: 200, body: '{"ok":true}', headers: { "Content-Type" => "application/json" })

    client = new_client
    client.get("/api/v1/test")

    assert_requested(:get, "#{BASE_URL}/api/v1/test")
  end

  # --- HTTP verbs ---

  def test_get_request
    stub_request(:get, "#{BASE_URL}/api/v1/faults")
      .to_return(status: 200, body: '{"faults":[]}', headers: { "Content-Type" => "application/json" })

    result = new_client.get("/api/v1/faults")

    assert_equal({ "faults" => [] }, result)
  end

  def test_post_request_with_body
    stub_request(:post, "#{BASE_URL}/api/v1/logs")
      .with(body: '{"log":{"message":"hi"}}')
      .to_return(status: 201, body: '{"id":1}', headers: { "Content-Type" => "application/json" })

    result = new_client.post("/api/v1/logs", { log: { message: "hi" } })

    assert_equal({ "id" => 1 }, result)
  end

  def test_post_without_body
    stub_request(:post, "#{BASE_URL}/api/v1/faults/1/resolve")
      .to_return(status: 200, body: '{"status":"resolved"}', headers: { "Content-Type" => "application/json" })

    result = new_client.post("/api/v1/faults/1/resolve")

    assert_equal({ "status" => "resolved" }, result)
  end

  def test_patch_request
    stub_request(:patch, "#{BASE_URL}/api/v1/faults/1")
      .with(body: '{"status":"ignored"}')
      .to_return(status: 200, body: '{"id":1}', headers: { "Content-Type" => "application/json" })

    result = new_client.patch("/api/v1/faults/1", { status: "ignored" })

    assert_equal({ "id" => 1 }, result)
  end

  def test_put_request
    stub_request(:put, "#{BASE_URL}/api/v1/faults/1/tags")
      .with(body: '{"tags":["a"]}')
      .to_return(status: 200, body: '{"tags":["a"]}', headers: { "Content-Type" => "application/json" })

    result = new_client.put("/api/v1/faults/1/tags", { tags: ["a"] })

    assert_equal({ "tags" => ["a"] }, result)
  end

  def test_delete_request
    stub_request(:delete, "#{BASE_URL}/api/v1/faults/1")
      .to_return(status: 200, body: '{"message":"deleted"}', headers: { "Content-Type" => "application/json" })

    result = new_client.delete("/api/v1/faults/1")

    assert_equal({ "message" => "deleted" }, result)
  end

  # --- Response handling ---

  def test_returns_nil_for_empty_body
    stub_request(:post, "#{BASE_URL}/api/v1/logs")
      .to_return(status: 204, body: "", headers: {})

    result = new_client.post("/api/v1/logs", { log: {} })

    assert_nil result
  end

  # --- Error responses ---

  def test_raises_authentication_error_on_401
    stub_request(:get, "#{BASE_URL}/api/v1/faults")
      .to_return(status: 401, body: '{"error":"unauthorized"}', headers: { "Content-Type" => "application/json" })

    assert_raises(CmdLog::AuthenticationError) do
      new_client.get("/api/v1/faults")
    end
  end

  def test_raises_rate_limit_error_on_429
    stub_request(:post, "#{BASE_URL}/api/v1/logs")
      .to_return(status: 429, body: "", headers: { "Retry-After" => "10" })

    err = assert_raises(CmdLog::RateLimitError) do
      new_client.post("/api/v1/logs", { log: {} })
    end

    assert_equal 10, err.retry_after
  end

  def test_raises_api_error_on_500
    stub_request(:get, "#{BASE_URL}/api/v1/faults")
      .to_return(status: 500, body: '{"error":"internal"}', headers: { "Content-Type" => "application/json" })

    err = assert_raises(CmdLog::ApiError) do
      new_client.get("/api/v1/faults")
    end

    assert_equal 500, err.status
    assert_match(/internal/, err.message)
  end

  def test_api_error_with_non_json_body
    stub_request(:get, "#{BASE_URL}/api/v1/faults")
      .to_return(status: 502, body: "Bad Gateway", headers: {})

    err = assert_raises(CmdLog::ApiError) do
      new_client.get("/api/v1/faults")
    end

    assert_equal 502, err.status
    assert_match(/Bad Gateway/, err.message)
  end

  # --- Retries ---

  def test_retries_on_rate_limit
    stub_request(:post, "#{BASE_URL}/api/v1/logs")
      .to_return(status: 429, body: "", headers: { "Retry-After" => "0" })
      .then
      .to_return(status: 200, body: '{"id":1}', headers: { "Content-Type" => "application/json" })

    client = new_client(max_retries: 1, retry_delay: 0)
    result = client.post("/api/v1/logs", { log: {} })

    assert_equal({ "id" => 1 }, result)
  end
end

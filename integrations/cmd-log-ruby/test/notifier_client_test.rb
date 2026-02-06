# frozen_string_literal: true

require "test_helper"

class NotifierClientTest < Minitest::Test
  BASE_URL = "http://localhost:8080"
  API_KEY  = "test-api-key"

  def setup
    WebMock.reset!
  end

  def new_client(**overrides)
    CmdLog::NotifierClient.new(
      api_url: overrides.fetch(:api_url, BASE_URL),
      api_key: overrides.fetch(:api_key, API_KEY),
      max_retries: overrides.fetch(:max_retries, 0),
      retry_delay: overrides.fetch(:retry_delay, 0),
      default_context: overrides[:default_context],
      default_server: overrides[:default_server],
      on_error: overrides.fetch(:on_error, ->(e) {})
    )
  end

  def stub_json(method, path, status: 200, body: "{}")
    stub_request(method, "#{BASE_URL}#{path}")
      .to_return(status: status, body: body, headers: { "Content-Type" => "application/json" })
  end

  # --- notify with Exception ---

  def test_notify_posts_exception_to_notices
    captured = nil
    stub_request(:post, "#{BASE_URL}/api/v1/notices")
      .with { |req| captured = JSON.parse(req.body); true }
      .to_return(status: 201, body: '{"id":"n1","fault_id":1}', headers: { "Content-Type" => "application/json" })

    err = begin
      raise ArgumentError, "bad argument"
    rescue => e
      e
    end

    client = new_client
    result = client.notify(err)

    assert_equal "n1", result["id"]
    assert_equal "ArgumentError", captured["error"]["class"]
    assert_equal "bad argument", captured["error"]["message"]
    assert captured["error"]["backtrace"].is_a?(Array)
    assert_equal "cmd_log-ruby", captured["notifier"]["name"]
  end

  # --- notify with String ---

  def test_notify_wraps_string_in_runtime_error
    captured = nil
    stub_request(:post, "#{BASE_URL}/api/v1/notices")
      .with { |req| captured = JSON.parse(req.body); true }
      .to_return(status: 201, body: '{"id":"n2","fault_id":2}', headers: { "Content-Type" => "application/json" })

    new_client.notify("something broke")

    assert_equal "RuntimeError", captured["error"]["class"]
    assert_equal "something broke", captured["error"]["message"]
  end

  # --- Context merging ---

  def test_notify_merges_default_and_per_call_context
    captured = nil
    stub_request(:post, "#{BASE_URL}/api/v1/notices")
      .with { |req| captured = JSON.parse(req.body); true }
      .to_return(status: 201, body: '{"id":"n3","fault_id":3}', headers: { "Content-Type" => "application/json" })

    client = new_client(default_context: { env: "test" })

    err = RuntimeError.new("ctx test")
    err.set_backtrace(["/app/test.rb:1:in `run'"])

    client.notify(err, context: { user_id: 99 })

    ctx = captured.dig("request", "context")
    assert_equal "test", ctx["env"]
    assert_equal 99, ctx["user_id"]
  end

  # --- Server context ---

  def test_notify_includes_server_context_with_hostname
    captured = nil
    stub_request(:post, "#{BASE_URL}/api/v1/notices")
      .with { |req| captured = JSON.parse(req.body); true }
      .to_return(status: 201, body: '{"id":"n4","fault_id":4}', headers: { "Content-Type" => "application/json" })

    client = new_client(default_server: { environment_name: "staging" })

    err = RuntimeError.new("server ctx")
    err.set_backtrace(["/app/test.rb:1:in `run'"])

    client.notify(err)

    server = captured["server"]
    assert_equal "staging", server["environment_name"]
    assert server.key?("hostname"), "expected auto-populated hostname"
  end

  # --- error_class override ---

  def test_notify_allows_error_class_override
    captured = nil
    stub_request(:post, "#{BASE_URL}/api/v1/notices")
      .with { |req| captured = JSON.parse(req.body); true }
      .to_return(status: 201, body: '{"id":"n5","fault_id":5}', headers: { "Content-Type" => "application/json" })

    err = RuntimeError.new("override")
    err.set_backtrace(["/app/test.rb:1:in `run'"])

    new_client.notify(err, error_class: "CustomError")

    assert_equal "CustomError", captured["error"]["class"]
  end

  # --- send_notice ---

  def test_send_notice_posts_raw_notice
    stub = stub_request(:post, "#{BASE_URL}/api/v1/notices")
      .with(body: '{"notifier":{"name":"test"}}')
      .to_return(status: 201, body: '{"id":"raw"}', headers: { "Content-Type" => "application/json" })

    result = new_client.send_notice({ notifier: { name: "test" } })

    assert_equal "raw", result["id"]
    assert_requested(stub)
  end

  # --- Fault CRUD ---

  def test_list_faults
    stub_json(:get, "/api/v1/faults", body: '{"faults":[],"total":0}')

    result = new_client.list_faults

    assert_equal({ "faults" => [], "total" => 0 }, result)
  end

  def test_list_faults_with_query_params
    stub = stub_request(:get, "#{BASE_URL}/api/v1/faults?q=payments&limit=10&offset=5")
      .to_return(status: 200, body: '{"faults":[]}', headers: { "Content-Type" => "application/json" })

    new_client.list_faults(query: "payments", limit: 10, offset: 5)

    assert_requested(stub)
  end

  def test_list_faults_encodes_query
    stub = stub_request(:get, /faults\?q=hello%20world/)
      .to_return(status: 200, body: '{"faults":[]}', headers: { "Content-Type" => "application/json" })

    new_client.list_faults(query: "hello world")

    assert_requested(stub)
  end

  def test_get_fault
    stub_json(:get, "/api/v1/faults/42", body: '{"id":42}')

    result = new_client.get_fault(42)

    assert_equal({ "id" => 42 }, result)
  end

  def test_update_fault
    stub = stub_request(:patch, "#{BASE_URL}/api/v1/faults/42")
      .with(body: '{"status":"ignored"}')
      .to_return(status: 200, body: '{"id":42}', headers: { "Content-Type" => "application/json" })

    new_client.update_fault(42, { status: "ignored" })

    assert_requested(stub)
  end

  def test_delete_fault
    stub_json(:delete, "/api/v1/faults/42", body: '{"message":"deleted"}')

    result = new_client.delete_fault(42)

    assert_equal "deleted", result["message"]
  end

  # --- Fault actions ---

  def test_resolve_fault
    stub_json(:post, "/api/v1/faults/1/resolve", body: '{"status":"resolved"}')

    result = new_client.resolve_fault(1)

    assert_equal "resolved", result["status"]
  end

  def test_unresolve_fault
    stub_json(:post, "/api/v1/faults/1/unresolve", body: '{"status":"open"}')

    result = new_client.unresolve_fault(1)

    assert_equal "open", result["status"]
  end

  def test_ignore_fault
    stub_json(:post, "/api/v1/faults/1/ignore", body: '{"status":"ignored"}')

    result = new_client.ignore_fault(1)

    assert_equal "ignored", result["status"]
  end

  def test_assign_fault
    stub = stub_request(:post, "#{BASE_URL}/api/v1/faults/1/assign")
      .with(body: '{"user_id":5}')
      .to_return(status: 200, body: '{"assigned_to":5}', headers: { "Content-Type" => "application/json" })

    new_client.assign_fault(1, 5)

    assert_requested(stub)
  end

  def test_add_fault_tags
    stub = stub_request(:post, "#{BASE_URL}/api/v1/faults/1/tags")
      .with(body: '{"tags":["critical","payments"]}')
      .to_return(status: 200, body: '{"tags":["critical","payments"]}', headers: { "Content-Type" => "application/json" })

    new_client.add_fault_tags(1, %w[critical payments])

    assert_requested(stub)
  end

  def test_replace_fault_tags
    stub = stub_request(:put, "#{BASE_URL}/api/v1/faults/1/tags")
      .with(body: '{"tags":["only-this"]}')
      .to_return(status: 200, body: '{"tags":["only-this"]}', headers: { "Content-Type" => "application/json" })

    new_client.replace_fault_tags(1, ["only-this"])

    assert_requested(stub)
  end

  def test_merge_faults
    stub = stub_request(:post, "#{BASE_URL}/api/v1/faults/10/merge")
      .with(body: '{"target_fault_id":20}')
      .to_return(status: 200, body: '{"message":"merged"}', headers: { "Content-Type" => "application/json" })

    new_client.merge_faults(10, 20)

    assert_requested(stub)
  end

  # --- Sub-resources ---

  def test_get_fault_notices
    stub_json(:get, "/api/v1/faults/1/notices", body: '{"notices":[]}')

    result = new_client.get_fault_notices(1)

    assert_equal({ "notices" => [] }, result)
  end

  def test_get_fault_notices_with_pagination
    stub = stub_request(:get, "#{BASE_URL}/api/v1/faults/1/notices?limit=5&offset=10")
      .to_return(status: 200, body: '{"notices":[]}', headers: { "Content-Type" => "application/json" })

    new_client.get_fault_notices(1, limit: 5, offset: 10)

    assert_requested(stub)
  end

  def test_get_fault_stats
    stub_json(:get, "/api/v1/faults/1/stats", body: '{"count":10}')

    result = new_client.get_fault_stats(1)

    assert_equal({ "count" => 10 }, result)
  end

  def test_get_fault_comments
    stub_json(:get, "/api/v1/faults/1/comments", body: '{"comments":[]}')

    result = new_client.get_fault_comments(1)

    assert_equal({ "comments" => [] }, result)
  end

  def test_create_fault_comment
    stub = stub_request(:post, "#{BASE_URL}/api/v1/faults/1/comments")
      .with(body: '{"comment":"looks bad","user_id":3}')
      .to_return(status: 201, body: '{"id":99}', headers: { "Content-Type" => "application/json" })

    new_client.create_fault_comment(1, "looks bad", user_id: 3)

    assert_requested(stub)
  end

  def test_get_fault_history
    stub_json(:get, "/api/v1/faults/1/history", body: '{"history":[]}')

    result = new_client.get_fault_history(1)

    assert_equal({ "history" => [] }, result)
  end

  # --- Users ---

  def test_get_users
    stub_json(:get, "/api/v1/users", body: '{"users":[]}')

    result = new_client.get_users

    assert_equal({ "users" => [] }, result)
  end
end

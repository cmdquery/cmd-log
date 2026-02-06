# frozen_string_literal: true

require "test_helper"

class ErrorsTest < Minitest::Test
  def test_base_error_inherits_from_standard_error
    assert CmdLog::Error < StandardError
  end

  def test_authentication_error_inherits_from_error
    assert CmdLog::AuthenticationError < CmdLog::Error
  end

  def test_rate_limit_error_inherits_from_error
    assert CmdLog::RateLimitError < CmdLog::Error
  end

  def test_rate_limit_error_stores_retry_after
    err = CmdLog::RateLimitError.new("slow down", retry_after: 30)

    assert_equal "slow down", err.message
    assert_equal 30, err.retry_after
  end

  def test_rate_limit_error_defaults
    err = CmdLog::RateLimitError.new

    assert_equal "Rate limit exceeded", err.message
    assert_nil err.retry_after
  end

  def test_api_error_inherits_from_error
    assert CmdLog::ApiError < CmdLog::Error
  end

  def test_api_error_stores_status_and_body
    err = CmdLog::ApiError.new("bad request", status: 400, response_body: '{"error":"invalid"}')

    assert_equal "bad request", err.message
    assert_equal 400, err.status
    assert_equal '{"error":"invalid"}', err.response_body
  end

  def test_configuration_error_inherits_from_error
    assert CmdLog::ConfigurationError < CmdLog::Error
  end
end

# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    CmdLog.reset!
  end

  def test_default_values
    config = CmdLog::Configuration.new

    assert_nil config.api_url
    assert_nil config.api_key
    assert_equal "ruby-app", config.service
    assert_equal true, config.enable_batching
    assert_equal 10, config.batch_size
    assert_equal 5, config.batch_interval
    assert_equal 3, config.max_retries
    assert_equal 1, config.retry_delay
    assert config.on_error.is_a?(Proc)
  end

  def test_attributes_are_writable
    config = CmdLog::Configuration.new

    config.api_url = "https://example.com"
    config.api_key = "test-key"
    config.service = "my-service"
    config.enable_batching = false
    config.batch_size = 50
    config.batch_interval = 10
    config.max_retries = 5
    config.retry_delay = 2

    assert_equal "https://example.com", config.api_url
    assert_equal "test-key", config.api_key
    assert_equal "my-service", config.service
    assert_equal false, config.enable_batching
    assert_equal 50, config.batch_size
    assert_equal 10, config.batch_interval
    assert_equal 5, config.max_retries
    assert_equal 2, config.retry_delay
  end

  def test_configure_block_sets_values
    CmdLog.configure do |c|
      c.api_url = "https://logs.test.com"
      c.api_key = "block-key"
      c.service = "block-service"
    end

    assert_equal "https://logs.test.com", CmdLog.configuration.api_url
    assert_equal "block-key", CmdLog.configuration.api_key
    assert_equal "block-service", CmdLog.configuration.service
  end

  def test_reset_clears_configuration
    CmdLog.configure do |c|
      c.api_url = "https://logs.test.com"
      c.api_key = "reset-key"
    end

    CmdLog.reset!

    assert_nil CmdLog.configuration.api_url
    assert_nil CmdLog.configuration.api_key
    assert_equal "ruby-app", CmdLog.configuration.service
  end

  def test_default_on_error_writes_to_stderr
    config = CmdLog::Configuration.new

    output = capture_io { config.on_error.call(RuntimeError.new("boom")) }[1]

    assert_match(/boom/, output)
  end
end

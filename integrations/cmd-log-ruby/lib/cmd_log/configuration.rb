# frozen_string_literal: true

module CmdLog
  # Holds global configuration for the CmdLog gem.
  #
  # Defaults mirror the TypeScript client:
  #   - enable_batching: true
  #   - batch_size:      10
  #   - batch_interval:  5 (seconds)
  #   - max_retries:     3
  #   - retry_delay:     1 (seconds)
  #
  # @example
  #   CmdLog.configure do |c|
  #     c.api_url  = "https://logs.example.com"
  #     c.api_key  = "your-api-key"
  #     c.service  = "my-app"
  #   end
  class Configuration
    # @return [String, nil] Base URL of the cmd-log service
    attr_accessor :api_url

    # @return [String, nil] API key for authentication
    attr_accessor :api_key

    # @return [String] Service name attached to every log entry
    attr_accessor :service

    # @return [Boolean] Whether to batch log entries before sending
    attr_accessor :enable_batching

    # @return [Integer] Number of log entries to accumulate before flushing
    attr_accessor :batch_size

    # @return [Numeric] Seconds between automatic batch flushes
    attr_accessor :batch_interval

    # @return [Integer] Maximum retry attempts for failed requests
    attr_accessor :max_retries

    # @return [Numeric] Base delay in seconds between retries (doubles each attempt)
    attr_accessor :retry_delay

    # @return [Proc, nil] Callback invoked when an error occurs (receives an Exception)
    attr_accessor :on_error

    def initialize
      @api_url         = nil
      @api_key         = nil
      @service         = "ruby-app"
      @enable_batching = true
      @batch_size      = 10
      @batch_interval  = 5
      @max_retries     = 3
      @retry_delay     = 1
      @on_error        = ->(error) { $stderr.puts("CmdLog error: #{error.message}") }
    end
  end
end

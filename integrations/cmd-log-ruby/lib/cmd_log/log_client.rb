# frozen_string_literal: true

require "time"

module CmdLog
  # Client for sending structured logs to the cmd-log ingestion service.
  #
  # Features:
  # - Automatic batching for efficient log transmission
  # - Retry logic with exponential backoff (handled by HttpClient)
  # - Rate-limit handling
  # - Queue management via BatchProcessor
  # - Failed-log tracking with manual retry support
  #
  # @example
  #   client = CmdLog::LogClient.new(
  #     api_url: "https://logs.example.com",
  #     api_key: "your-key",
  #     service: "my-app",
  #   )
  #
  #   client.info("User signed in", user_id: 42)
  #   client.error("Payment failed", order_id: 99)
  #   client.flush
  #   client.destroy
  class LogClient
    LOG_LEVELS = %w[DEBUG INFO WARN WARNING ERROR FATAL CRITICAL].freeze

    # @param api_url         [String]  Base URL of the cmd-log service
    # @param api_key         [String]  API key for authentication
    # @param service         [String]  Service name attached to every log entry
    # @param enable_batching [Boolean] Whether to batch log entries (default: true)
    # @param batch_size      [Integer] Entries per batch (default: 10)
    # @param batch_interval  [Numeric] Seconds between flushes (default: 5)
    # @param max_retries     [Integer] Max retries for failed requests (default: 3)
    # @param retry_delay     [Numeric] Base retry delay in seconds (default: 1)
    # @param on_error        [Proc, nil] Error callback
    def initialize(api_url:, api_key:, service: "ruby-app",
                   enable_batching: true, batch_size: 10, batch_interval: 5,
                   max_retries: 3, retry_delay: 1, on_error: nil)
      @service         = service
      @enable_batching = enable_batching
      @on_error        = on_error || ->(e) { $stderr.puts("CmdLog::LogClient error: #{e.message}") }

      @http = HttpClient.new(
        api_url: api_url,
        api_key: api_key,
        max_retries: max_retries,
        retry_delay: retry_delay,
        on_error: @on_error
      )

      @failed_logs = []
      @failed_mutex = Mutex.new

      @batch_processor = nil
      if @enable_batching
        @batch_processor = BatchProcessor.new(
          batch_size: batch_size,
          batch_interval: batch_interval
        ) { |items| send_batch(items) }
      end
    end

    # -----------------------------------------------------------------------
    # Core logging
    # -----------------------------------------------------------------------

    # Send a log entry at the given level.
    #
    # @param level    [String]            One of LOG_LEVELS
    # @param message  [String]            Log message
    # @param metadata [Hash]              Arbitrary metadata
    def log(level, message, metadata = {})
      level = level.to_s.upcase
      entry = create_entry(level, message, metadata)

      if @enable_batching
        @batch_processor.push(entry)
      else
        send_log(entry)
      end
    end

    # Convenience methods for each log level.
    # @!method debug(message, metadata = {})
    # @!method info(message, metadata = {})
    # @!method warn(message, metadata = {})
    # @!method error(message, metadata = {})
    # @!method fatal(message, metadata = {})
    %w[debug info warn error fatal].each do |level|
      define_method(level) do |message, metadata = {}|
        log(level, message, metadata)
      end
    end

    # -----------------------------------------------------------------------
    # Direct send (bypasses batching)
    # -----------------------------------------------------------------------

    # Send a single log entry directly to the API.
    #
    # @param entry [Hash] A log entry hash
    def send_log(entry)
      @http.post("/api/v1/logs", { log: entry })
    rescue => e
      @on_error.call(e)
      @failed_mutex.synchronize { @failed_logs << entry }
    end

    # -----------------------------------------------------------------------
    # Batch & lifecycle
    # -----------------------------------------------------------------------

    # Flush queued logs immediately.
    def flush
      @batch_processor&.flush
    end

    # Shut down the client: stop the batch timer and flush remaining logs.
    # Safe to call multiple times.
    def destroy
      @batch_processor&.shutdown
    end

    # Return a copy of log entries that failed to send.
    #
    # @return [Array<Hash>]
    def failed_logs
      @failed_mutex.synchronize { @failed_logs.dup }
    end

    # Retry all previously failed log entries.
    def retry_failed_logs
      logs = @failed_mutex.synchronize { @failed_logs.dup }
      @failed_mutex.synchronize { @failed_logs.clear }

      logs.each { |entry| send_log(entry) }
    end

    private

    # Build a log entry hash matching the server's expected format.
    def create_entry(level, message, metadata)
      entry = {
        timestamp: Time.now.utc.iso8601(3),
        service: @service,
        level: level,
        message: message.to_s
      }
      entry[:metadata] = metadata unless metadata.nil? || metadata.empty?
      entry
    end

    # Send a batch of log entries via the batch endpoint.
    def send_batch(entries)
      return if entries.nil? || entries.empty?

      result = @http.post("/api/v1/logs/batch", { logs: entries })

      # Warn about partial failures
      if result.is_a?(Hash) && result["errors"]&.any?
        $stderr.puts("CmdLog: some logs were rejected: #{result["errors"]}")
      end
    rescue RateLimitError
      # Re-queue individual entries for retry
      entries.each { |e| @batch_processor&.push(e) }
    rescue => e
      @on_error.call(e)
      # Track entries that failed permanently
      @failed_mutex.synchronize { @failed_logs.concat(entries) }
    end
  end
end

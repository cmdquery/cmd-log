# frozen_string_literal: true

require_relative "cmd_log/version"
require_relative "cmd_log/errors"
require_relative "cmd_log/configuration"
require_relative "cmd_log/http_client"
require_relative "cmd_log/batch_processor"
require_relative "cmd_log/backtrace_parser"
require_relative "cmd_log/log_client"
require_relative "cmd_log/notifier_client"
require_relative "cmd_log/middleware/rack_middleware"

module CmdLog
  class << self
    # Returns the global configuration instance.
    def configuration
      @configuration ||= Configuration.new
    end

    # Yields the global configuration for modification.
    #
    #   CmdLog.configure do |c|
    #     c.api_url = "https://logs.example.com"
    #     c.api_key = "your-api-key"
    #     c.service = "my-app"
    #   end
    def configure
      yield(configuration) if block_given?
      configuration
    end

    # Resets the global configuration and cached client instances.
    def reset!
      @configuration = Configuration.new
      @logger = nil
      @notifier = nil
    end

    # Returns a global LogClient instance built from the global configuration.
    # Lazily created on first access.
    def logger
      @logger ||= LogClient.new(
        api_url: configuration.api_url,
        api_key: configuration.api_key,
        service: configuration.service,
        enable_batching: configuration.enable_batching,
        batch_size: configuration.batch_size,
        batch_interval: configuration.batch_interval,
        max_retries: configuration.max_retries,
        retry_delay: configuration.retry_delay,
        on_error: configuration.on_error
      )
    end

    # Returns a global NotifierClient instance built from the global configuration.
    # Lazily created on first access.
    def notifier
      @notifier ||= NotifierClient.new(
        api_url: configuration.api_url,
        api_key: configuration.api_key,
        on_error: configuration.on_error
      )
    end
  end
end

# Auto-load Rails integration when Rails is present
require_relative "cmd_log/railtie" if defined?(Rails::Railtie)

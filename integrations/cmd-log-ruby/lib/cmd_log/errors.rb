# frozen_string_literal: true

module CmdLog
  # Base error class for all CmdLog errors.
  class Error < StandardError; end

  # Raised when the server returns 401 Unauthorized.
  class AuthenticationError < Error; end

  # Raised when the server returns 429 Too Many Requests.
  class RateLimitError < Error
    # @return [Integer, nil] Seconds to wait before retrying (from Retry-After header)
    attr_reader :retry_after

    def initialize(message = "Rate limit exceeded", retry_after: nil)
      @retry_after = retry_after
      super(message)
    end
  end

  # Raised for non-success HTTP responses that are not auth or rate-limit errors.
  class ApiError < Error
    # @return [Integer] HTTP status code
    attr_reader :status

    # @return [String, nil] Error body returned by the server
    attr_reader :response_body

    def initialize(message, status:, response_body: nil)
      @status = status
      @response_body = response_body
      super(message)
    end
  end

  # Raised when required configuration is missing.
  class ConfigurationError < Error; end
end

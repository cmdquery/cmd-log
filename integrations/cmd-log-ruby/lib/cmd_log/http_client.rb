# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module CmdLog
  # Low-level HTTP wrapper used by LogClient and NotifierClient.
  #
  # Handles:
  # - API key authentication via X-API-Key header
  # - JSON request/response serialization
  # - Exponential-backoff retries for transient failures (5xx, timeouts)
  # - Rate-limit handling (429) with Retry-After header
  # - Typed error classes for different failure modes
  class HttpClient
    # Default timeouts (seconds)
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 10

    # @param api_url    [String]  Base URL of the cmd-log service
    # @param api_key    [String]  API key for authentication
    # @param max_retries [Integer] Maximum retry attempts (default: 3)
    # @param retry_delay [Numeric] Base delay in seconds between retries (default: 1)
    # @param on_error   [Proc, nil] Optional error callback
    def initialize(api_url:, api_key:, max_retries: 3, retry_delay: 1, on_error: nil)
      raise ConfigurationError, "api_url is required" if api_url.nil? || api_url.empty?
      raise ConfigurationError, "api_key is required" if api_key.nil? || api_key.empty?

      @base_uri    = URI.parse(api_url.chomp("/"))
      @api_key     = api_key
      @max_retries = max_retries
      @retry_delay = retry_delay
      @on_error    = on_error
      @mutex       = Mutex.new
      @connection  = nil
    end

    # Perform an HTTP request.
    #
    # @param method [String]     HTTP method ("GET", "POST", "PATCH", "PUT", "DELETE")
    # @param path   [String]     Request path (e.g. "/api/v1/logs")
    # @param body   [Hash, nil]  Request body (will be JSON-encoded)
    # @return [Hash, nil]        Parsed JSON response body
    def request(method, path, body: nil)
      attempts = 0

      begin
        attempts += 1
        response = execute_request(method, path, body)
        handle_response(response, method, path)
      rescue RateLimitError => e
        if attempts <= @max_retries
          delay = e.retry_after || (@retry_delay * (2**(attempts - 1)))
          sleep(delay)
          retry
        end
        raise
      rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED,
             Errno::ECONNRESET, Errno::EHOSTUNREACH, IOError => e
        if attempts <= @max_retries
          sleep(@retry_delay * (2**(attempts - 1)))
          reset_connection!
          retry
        end
        error = Error.new("#{method} #{path} failed after #{@max_retries} retries: #{e.message}")
        @on_error&.call(error)
        raise error
      end
    end

    # Convenience methods for common HTTP verbs.

    def get(path)
      request("GET", path)
    end

    def post(path, body = nil)
      request("POST", path, body: body)
    end

    def patch(path, body = nil)
      request("PATCH", path, body: body)
    end

    def put(path, body = nil)
      request("PUT", path, body: body)
    end

    def delete(path)
      request("DELETE", path)
    end

    private

    # Build and send the raw Net::HTTP request.
    def execute_request(method, path, body)
      uri = @base_uri.dup
      uri.path = path

      req = build_request(method, uri, body)
      connection.request(req)
    rescue IOError, Errno::EPIPE
      # Connection went stale; reconnect and retry once
      reset_connection!
      req = build_request(method, uri, body)
      connection.request(req)
    end

    # Build a Net::HTTP request object with headers and optional JSON body.
    def build_request(method, uri, body)
      klass = case method.upcase
              when "GET"    then Net::HTTP::Get
              when "POST"   then Net::HTTP::Post
              when "PATCH"  then Net::HTTP::Patch
              when "PUT"    then Net::HTTP::Put
              when "DELETE" then Net::HTTP::Delete
              else raise ArgumentError, "Unsupported HTTP method: #{method}"
              end

      req = klass.new(uri)
      req["X-API-Key"]    = @api_key
      req["Content-Type"] = "application/json"
      req["Accept"]       = "application/json"
      req["User-Agent"]   = "cmd_log-ruby/#{CmdLog::VERSION}"
      req.body = JSON.generate(body) if body
      req
    end

    # Interpret the response and raise typed errors for failures.
    def handle_response(response, method, path)
      case response.code.to_i
      when 200..299
        return nil if response.body.nil? || response.body.empty?

        JSON.parse(response.body)
      when 401
        raise AuthenticationError, "#{method} #{path}: Authentication failed -- check your API key"
      when 429
        retry_after = response["Retry-After"]&.to_i
        raise RateLimitError.new(
          "#{method} #{path}: Rate limit exceeded",
          retry_after: retry_after
        )
      else
        body_text = response.body
        error_msg = begin
          data = JSON.parse(body_text)
          data["error"] || data["details"] || data["message"] || body_text
        rescue JSON::ParserError
          body_text
        end

        raise ApiError.new(
          "#{method} #{path} failed: #{response.code} - #{error_msg}",
          status: response.code.to_i,
          response_body: body_text
        )
      end
    end

    # Return (or create) a persistent connection with keep-alive.
    def connection
      @mutex.synchronize do
        if @connection.nil? || !@connection.started?
          @connection = Net::HTTP.new(@base_uri.host, @base_uri.port)
          @connection.use_ssl       = (@base_uri.scheme == "https")
          @connection.open_timeout  = OPEN_TIMEOUT
          @connection.read_timeout  = READ_TIMEOUT
          @connection.keep_alive_timeout = 30
          @connection.start
        end
        @connection
      end
    end

    # Close and discard the current connection so a fresh one is created.
    def reset_connection!
      @mutex.synchronize do
        @connection&.finish rescue nil
        @connection = nil
      end
    end
  end
end

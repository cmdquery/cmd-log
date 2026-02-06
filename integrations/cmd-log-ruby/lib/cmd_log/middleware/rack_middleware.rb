# frozen_string_literal: true

require "securerandom"

module CmdLog
  module Middleware
    # Rack middleware that automatically logs HTTP requests and responses
    # to the cmd-log service via the global CmdLog.logger.
    #
    # @example config.ru
    #   require "cmd_log"
    #   use CmdLog::Middleware::RackMiddleware
    #
    # @example Rails config/application.rb
    #   config.middleware.insert_before ActionDispatch::ShowExceptions,
    #     CmdLog::Middleware::RackMiddleware
    class RackMiddleware
      # Paths that are skipped by default (assets, health checks, etc.)
      DEFAULT_SKIP_PATHS = %w[/assets /packs /favicon.ico /health].freeze

      # @param app        [#call]          The downstream Rack app
      # @param skip_paths [Array<String>]  Path prefixes to skip logging for
      # @param logger     [CmdLog::LogClient, nil] Custom log client (defaults to CmdLog.logger)
      def initialize(app, skip_paths: DEFAULT_SKIP_PATHS, logger: nil)
        @app        = app
        @skip_paths = skip_paths
        @logger     = logger
      end

      def call(env)
        path = env["PATH_INFO"] || "/"
        return @app.call(env) if skip?(path)

        request_id = env["HTTP_X_REQUEST_ID"] || SecureRandom.uuid
        env["cmd_log.request_id"] = request_id

        start_time = monotonic_now

        log_client.info("HTTP Request", {
          request_id: request_id,
          method: env["REQUEST_METHOD"],
          path: path,
          query_string: env["QUERY_STRING"],
          ip: env["HTTP_X_FORWARDED_FOR"] || env["REMOTE_ADDR"],
          user_agent: env["HTTP_USER_AGENT"],
          referer: env["HTTP_REFERER"]
        })

        begin
          status, headers, response = @app.call(env)

          duration_ms = ((monotonic_now - start_time) * 1000).round(2)
          log_client.info("HTTP Response", {
            request_id: request_id,
            status: status,
            duration_ms: duration_ms,
            content_type: headers["Content-Type"]
          })

          [status, headers, response]
        rescue => e
          duration_ms = ((monotonic_now - start_time) * 1000).round(2)
          log_client.error("Request error", {
            request_id: request_id,
            duration_ms: duration_ms,
            error: {
              class: e.class.name,
              message: e.message,
              backtrace: e.backtrace&.first(10)
            }
          })
          raise
        end
      end

      private

      def log_client
        @logger || CmdLog.logger
      end

      def skip?(path)
        @skip_paths.any? { |prefix| path.start_with?(prefix) }
      end

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end

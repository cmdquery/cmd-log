# frozen_string_literal: true

module CmdLog
  # Rails integration that auto-configures CmdLog from environment variables
  # or Rails credentials when the gem is loaded in a Rails application.
  #
  # Environment variables (take precedence):
  #   CMD_LOG_URL     -- Base URL of the cmd-log service
  #   CMD_LOG_API_KEY -- API key for authentication
  #   CMD_LOG_SERVICE -- Service name (defaults to Rails app name)
  #
  # Rails credentials fallback:
  #   Rails.application.credentials.dig(:cmd_log, :api_url)
  #   Rails.application.credentials.dig(:cmd_log, :api_key)
  #   Rails.application.credentials.dig(:cmd_log, :service)
  class Railtie < Rails::Railtie
    initializer "cmd_log.configure" do |app|
      CmdLog.configure do |c|
        c.api_url = ENV["CMD_LOG_URL"] ||
                    app.credentials.dig(:cmd_log, :api_url)

        c.api_key = ENV["CMD_LOG_API_KEY"] ||
                    app.credentials.dig(:cmd_log, :api_key)

        c.service = ENV["CMD_LOG_SERVICE"] ||
                    app.credentials.dig(:cmd_log, :service) ||
                    app.class.module_parent_name.underscore rescue "rails-app"
      end
    end

    # Insert Rack middleware for automatic request logging (only when configured)
    initializer "cmd_log.middleware" do |app|
      config.after_initialize do
        if CmdLog.configuration.api_url && CmdLog.configuration.api_key
          app.middleware.insert_before(
            ActionDispatch::ShowExceptions,
            CmdLog::Middleware::RackMiddleware
          )
        end
      end
    end

    # Flush pending logs when the process exits
    config.after_initialize do
      at_exit do
        CmdLog.logger.destroy if CmdLog.instance_variable_get(:@logger)
      rescue => e
        $stderr.puts("CmdLog: error during shutdown flush: #{e.message}")
      end
    end
  end
end

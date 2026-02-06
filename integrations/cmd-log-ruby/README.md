# cmd_log

Ruby client for the [cmd-log](../../README.md) service -- structured log ingestion and Honeybadger-compatible error tracking.

## Features

- **LogClient** -- Send structured logs with automatic batching, retries, and rate-limit handling
- **NotifierClient** -- Report errors and manage faults (resolve, ignore, assign, tag, merge, comment)
- **Rack middleware** -- Automatic HTTP request/response logging
- **Rails integration** -- Auto-configure from environment variables or Rails credentials
- **Zero dependencies** -- Uses only Ruby stdlib (`net/http`, `json`, `uri`)

## Installation

Add to your Gemfile:

```ruby
gem "cmd_log", path: "integrations/cmd-log-ruby"
```

Or install directly:

```bash
gem install cmd_log
```

## Quick Start

### Log Ingestion

```ruby
require "cmd_log"

client = CmdLog::LogClient.new(
  api_url: "https://logs.example.com",
  api_key: "your-api-key",
  service: "my-app",
)

client.info("User signed in", user_id: 42)
client.warn("Slow query detected", duration_ms: 350, query: "SELECT ...")
client.error("Payment failed", order_id: 99, reason: "declined")

# Flush pending logs and shut down
client.destroy
```

### Error Tracking

```ruby
notifier = CmdLog::NotifierClient.new(
  api_url: "https://logs.example.com",
  api_key: "your-api-key",
)

begin
  dangerous_work
rescue => e
  notifier.notify(e, context: { user_id: 42 })
end
```

## Configuration

### Per-client Configuration

Both `LogClient` and `NotifierClient` accept configuration directly:

```ruby
client = CmdLog::LogClient.new(
  api_url:         "https://logs.example.com",
  api_key:         "your-api-key",
  service:         "my-app",
  enable_batching: true,   # default
  batch_size:      10,     # default
  batch_interval:  5,      # seconds, default
  max_retries:     3,      # default
  retry_delay:     1,      # seconds, default
  on_error:        ->(e) { MyLogger.error(e.message) },
)
```

### Global Configuration

For convenience (especially in Rails), configure once globally:

```ruby
CmdLog.configure do |c|
  c.api_url  = ENV["CMD_LOG_URL"]
  c.api_key  = ENV["CMD_LOG_API_KEY"]
  c.service  = "my-app"
end

# Then use global instances anywhere:
CmdLog.logger.info("Application started")
CmdLog.notifier.notify(exception)
```

## LogClient API

### Logging Methods

```ruby
client.log("INFO", "message", optional_metadata_hash)

# Convenience methods:
client.debug("message", key: "value")
client.info("message", key: "value")
client.warn("message", key: "value")
client.error("message", key: "value")
client.fatal("message", key: "value")
```

### Lifecycle

```ruby
client.flush           # Flush queued logs immediately
client.destroy         # Stop batch timer and flush remaining logs
client.failed_logs     # Get logs that failed to send
client.retry_failed_logs  # Retry all failed logs
```

### Direct Send (Bypass Batching)

```ruby
entry = {
  timestamp: Time.now.utc.iso8601(3),
  service:   "my-app",
  level:     "ERROR",
  message:   "Something broke",
  metadata:  { request_id: "abc-123" },
}

client.send_log(entry)
```

## NotifierClient API

### Error Reporting

```ruby
# High-level -- accepts Exception or String
notifier.notify(exception,
  error_class: "CustomError",        # override error class name
  context:     { user_id: 42 },      # extra context
  request:     { url: "/checkout" }, # request info
  server:      { environment_name: "production" },
  breadcrumbs: { enabled: true, trail: [...] },
)

# Low-level -- send a fully formed notice hash
notifier.send_notice({
  notifier: { name: "my-lib", version: "1.0", url: "..." },
  error:    { class: "RuntimeError", message: "boom", backtrace: [...] },
})
```

### Fault CRUD

```ruby
notifier.list_faults(query: "payments", limit: 20, offset: 0)
notifier.get_fault(123)
notifier.update_fault(123, { resolved: true })
notifier.delete_fault(123)
```

### Fault Actions

```ruby
notifier.resolve_fault(123)
notifier.unresolve_fault(123)
notifier.ignore_fault(123)
notifier.assign_fault(123, user_id)    # pass nil to unassign
notifier.add_fault_tags(123, ["critical", "payments"])
notifier.replace_fault_tags(123, ["low-priority"])
notifier.merge_faults(source_id, target_id)
```

### Fault Sub-resources

```ruby
notifier.get_fault_notices(123, limit: 50)
notifier.get_fault_stats(123)
notifier.get_fault_comments(123)
notifier.create_fault_comment(123, "Investigating", user_id: 1)
notifier.get_fault_history(123)
notifier.get_users
```

## Rack Middleware

Automatically logs every HTTP request and response:

```ruby
# config.ru
require "cmd_log"

CmdLog.configure do |c|
  c.api_url = ENV["CMD_LOG_URL"]
  c.api_key = ENV["CMD_LOG_API_KEY"]
  c.service = "my-app"
end

use CmdLog::Middleware::RackMiddleware
run MyApp
```

Options:

```ruby
use CmdLog::Middleware::RackMiddleware,
  skip_paths: ["/assets", "/health"],  # paths to skip (default: /assets, /packs, /favicon.ico, /health)
  logger: custom_log_client            # override the log client instance
```

## Rails Integration

When `cmd_log` is loaded in a Rails application, a Railtie automatically:

1. Reads configuration from environment variables or Rails credentials
2. Inserts the Rack middleware for request logging
3. Registers an `at_exit` hook to flush pending logs

### Environment Variables

```bash
export CMD_LOG_URL=https://logs.example.com
export CMD_LOG_API_KEY=your-api-key
export CMD_LOG_SERVICE=my-rails-app
```

### Rails Credentials

```yaml
# config/credentials.yml.enc
cmd_log:
  api_url: https://logs.example.com
  api_key: your-api-key
  service: my-rails-app
```

### Manual Override

You can still configure manually in an initializer:

```ruby
# config/initializers/cmd_log.rb
CmdLog.configure do |c|
  c.api_url        = ENV["CMD_LOG_URL"]
  c.api_key        = ENV["CMD_LOG_API_KEY"]
  c.service        = "my-rails-app"
  c.enable_batching = true
  c.batch_size     = 25
  c.on_error       = ->(e) { Rails.logger.error("CmdLog: #{e.message}") }
end
```

### Usage in Controllers

```ruby
class ApplicationController < ActionController::Base
  rescue_from StandardError do |e|
    CmdLog.notifier.notify(e, context: {
      user_id:    current_user&.id,
      request_id: request.request_id,
    })
    raise
  end
end
```

### Usage in Jobs

```ruby
class PaymentJob < ApplicationJob
  def perform(order_id)
    CmdLog.logger.info("Processing payment", order_id: order_id)
    process_payment(order_id)
    CmdLog.logger.info("Payment complete", order_id: order_id)
  rescue => e
    CmdLog.notifier.notify(e, context: { order_id: order_id })
    raise
  end
end
```

## Error Handling

The gem raises typed errors for different failure modes:

| Error Class                   | HTTP Status | When                          |
|-------------------------------|-------------|-------------------------------|
| `CmdLog::AuthenticationError` | 401         | Invalid or missing API key    |
| `CmdLog::RateLimitError`      | 429         | Too many requests             |
| `CmdLog::ApiError`            | Other 4xx/5xx | Server returned an error    |
| `CmdLog::ConfigurationError`  | --          | Missing required config       |

The `on_error` callback is invoked for non-fatal errors (e.g., batch send failures). Fatal configuration errors raise immediately.

## Requirements

- Ruby >= 3.0
- No external gems required

## License

MIT

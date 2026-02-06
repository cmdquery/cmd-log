# frozen_string_literal: true

require_relative "lib/cmd_log/version"

Gem::Specification.new do |spec|
  spec.name          = "cmd_log"
  spec.version       = CmdLog::VERSION
  spec.authors       = ["cmd-log contributors"]
  spec.email         = []

  spec.summary       = "Ruby client for the cmd-log service"
  spec.description   = "Client library for structured log ingestion and Honeybadger-compatible " \
                        "error tracking with the cmd-log service. Supports batching, retries, " \
                        "rate-limit handling, and full fault lifecycle management."
  spec.homepage      = "https://github.com/YOUR_USERNAME/cmd-log"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/YOUR_USERNAME/cmd-log/tree/main/integrations/cmd-log-ruby"

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]

  # Zero runtime dependencies -- uses only Ruby stdlib (net/http, json, uri, etc.)
end

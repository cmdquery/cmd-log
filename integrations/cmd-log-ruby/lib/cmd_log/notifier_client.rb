# frozen_string_literal: true

require "socket"

module CmdLog
  # Client for interacting with the cmd-log fault / error-tracking API.
  #
  # Supports:
  # - Sending error notices (Honeybadger-compatible format)
  # - Full fault CRUD and actions (resolve, ignore, assign, tag, merge)
  # - Fault sub-resources (notices, stats, comments, history)
  #
  # @example
  #   notifier = CmdLog::NotifierClient.new(
  #     api_url: "https://logs.example.com",
  #     api_key: "your-key",
  #   )
  #
  #   begin
  #     dangerous_work
  #   rescue => e
  #     notifier.notify(e, context: { user_id: 42 })
  #   end
  #
  #   notifier.list_faults(query: "payments", limit: 20)
  #   notifier.resolve_fault(123)
  class NotifierClient
    NOTIFIER_DEFAULTS = {
      name: "cmd_log-ruby",
      version: CmdLog::VERSION,
      url: "https://github.com/YOUR_USERNAME/cmd-log"
    }.freeze

    # @param api_url         [String]     Base URL of the cmd-log service
    # @param api_key         [String]     API key for authentication
    # @param notifier        [Hash, nil]  Override notifier metadata { name:, version:, url: }
    # @param default_server  [Hash, nil]  Default server context merged into every notice
    # @param default_context [Hash, nil]  Default request context merged into every notice
    # @param max_retries     [Integer]    Max retries (default: 3)
    # @param retry_delay     [Numeric]    Base retry delay in seconds (default: 1)
    # @param on_error        [Proc, nil]  Error callback
    def initialize(api_url:, api_key:, notifier: nil, default_server: nil,
                   default_context: nil, max_retries: 3, retry_delay: 1, on_error: nil)
      @notifier_meta   = notifier || NOTIFIER_DEFAULTS
      @default_server  = default_server
      @default_context = default_context || {}
      @on_error        = on_error || ->(e) { $stderr.puts("CmdLog::NotifierClient error: #{e.message}") }

      @http = HttpClient.new(
        api_url: api_url,
        api_key: api_key,
        max_retries: max_retries,
        retry_delay: retry_delay,
        on_error: @on_error
      )
    end

    # -----------------------------------------------------------------------
    # Notice ingestion
    # -----------------------------------------------------------------------

    # High-level method: report an error.
    #
    # Accepts a Ruby Exception (or a string) and automatically captures a
    # backtrace, enriches with server context, and sends the notice to
    # POST /api/v1/notices.
    #
    # @param error   [Exception, String] The error to report
    # @param options [Hash] Additional options
    # @option options [String]  :error_class  Override the error class name
    # @option options [Hash]    :context      Extra context merged into request.context
    # @option options [Hash]    :request      Request context (url, component, action, params, etc.)
    # @option options [Hash]    :server       Server context (environment_name, hostname, etc.)
    # @option options [Hash]    :breadcrumbs  Breadcrumb trail { enabled:, trail: [] }
    # @return [Hash] Response with "id" and "fault_id"
    def notify(error, **options)
      err = error.is_a?(Exception) ? error : RuntimeError.new(error.to_s)
      backtrace = BacktraceParser.parse(err.backtrace)

      notice = {
        notifier: @notifier_meta,
        error: {
          class: options[:error_class] || err.class.name,
          message: err.message,
          backtrace: backtrace
        }
      }

      # Merge request context
      merged_context = @default_context.merge(options[:context] || {})

      if options[:request] || !merged_context.empty?
        notice[:request] = {
          **(options[:request] || {}),
          context: {
            **(options.dig(:request, :context) || {}),
            **merged_context
          }
        }
      end

      # Merge server context
      server = build_server_context(options[:server])
      notice[:server] = server if server

      # Breadcrumbs
      notice[:breadcrumbs] = options[:breadcrumbs] if options[:breadcrumbs]

      send_notice(notice)
    rescue => e
      @on_error.call(e)
      raise
    end

    # Low-level method: send a fully formed notice request directly.
    #
    # @param notice [Hash] A Honeybadger-compatible notice hash
    # @return [Hash] Response with "id" and "fault_id"
    def send_notice(notice)
      @http.post("/api/v1/notices", notice)
    end

    # -----------------------------------------------------------------------
    # Fault CRUD
    # -----------------------------------------------------------------------

    # List faults with optional search query and pagination.
    #
    # @param query  [String, nil]  Search query
    # @param limit  [Integer, nil] Max results
    # @param offset [Integer, nil] Pagination offset
    # @return [Hash] { "faults" => [...], "total" => n, "limit" => n, "offset" => n }
    def list_faults(query: nil, limit: nil, offset: nil)
      params = []
      params << "q=#{uri_encode(query)}" if query
      params << "limit=#{limit}" if limit
      params << "offset=#{offset}" if offset

      qs = params.empty? ? "" : "?#{params.join("&")}"
      @http.get("/api/v1/faults#{qs}")
    end

    # Get a single fault by ID.
    #
    # @param id [Integer] Fault ID
    # @return [Hash] Fault object
    def get_fault(id)
      @http.get("/api/v1/faults/#{id}")
    end

    # Update a fault (partial update).
    #
    # @param id      [Integer] Fault ID
    # @param updates [Hash]    Fields to update
    # @return [Hash] Updated fault
    def update_fault(id, updates)
      @http.patch("/api/v1/faults/#{id}", updates)
    end

    # Delete a fault.
    #
    # @param id [Integer] Fault ID
    # @return [Hash] { "message" => "..." }
    def delete_fault(id)
      @http.delete("/api/v1/faults/#{id}")
    end

    # -----------------------------------------------------------------------
    # Fault actions
    # -----------------------------------------------------------------------

    # Resolve a fault.
    #
    # @param id [Integer] Fault ID
    # @return [Hash] Updated fault
    def resolve_fault(id)
      @http.post("/api/v1/faults/#{id}/resolve")
    end

    # Unresolve a fault.
    #
    # @param id [Integer] Fault ID
    # @return [Hash] Updated fault
    def unresolve_fault(id)
      @http.post("/api/v1/faults/#{id}/unresolve")
    end

    # Ignore a fault.
    #
    # @param id [Integer] Fault ID
    # @return [Hash] Updated fault
    def ignore_fault(id)
      @http.post("/api/v1/faults/#{id}/ignore")
    end

    # Assign a fault to a user (pass nil to unassign).
    #
    # @param id      [Integer]      Fault ID
    # @param user_id [Integer, nil] User ID to assign (nil to unassign)
    # @return [Hash] Updated fault
    def assign_fault(id, user_id)
      @http.post("/api/v1/faults/#{id}/assign", { user_id: user_id })
    end

    # Add tags to a fault (appends to existing).
    #
    # @param id   [Integer]        Fault ID
    # @param tags [Array<String>]  Tags to add
    # @return [Hash] Updated fault
    def add_fault_tags(id, tags)
      @http.post("/api/v1/faults/#{id}/tags", { tags: tags })
    end

    # Replace all tags on a fault.
    #
    # @param id   [Integer]        Fault ID
    # @param tags [Array<String>]  Replacement tags
    # @return [Hash] Updated fault
    def replace_fault_tags(id, tags)
      @http.put("/api/v1/faults/#{id}/tags", { tags: tags })
    end

    # Merge a fault into a target fault.
    #
    # @param source_id [Integer] Source fault ID
    # @param target_id [Integer] Target fault ID
    # @return [Hash] { "message" => "..." }
    def merge_faults(source_id, target_id)
      @http.post("/api/v1/faults/#{source_id}/merge", { target_fault_id: target_id })
    end

    # -----------------------------------------------------------------------
    # Fault sub-resources
    # -----------------------------------------------------------------------

    # Get individual error occurrences (notices) for a fault.
    #
    # @param id     [Integer]      Fault ID
    # @param limit  [Integer, nil] Max results
    # @param offset [Integer, nil] Pagination offset
    # @return [Hash] { "notices" => [...], "limit" => n, "offset" => n }
    def get_fault_notices(id, limit: nil, offset: nil)
      params = []
      params << "limit=#{limit}" if limit
      params << "offset=#{offset}" if offset

      qs = params.empty? ? "" : "?#{params.join("&")}"
      @http.get("/api/v1/faults/#{id}/notices#{qs}")
    end

    # Get occurrence statistics for a fault.
    #
    # @param id [Integer] Fault ID
    # @return [Hash]
    def get_fault_stats(id)
      @http.get("/api/v1/faults/#{id}/stats")
    end

    # Get comments on a fault.
    #
    # @param id [Integer] Fault ID
    # @return [Hash] { "comments" => [...] }
    def get_fault_comments(id)
      @http.get("/api/v1/faults/#{id}/comments")
    end

    # Create a comment on a fault.
    #
    # @param id      [Integer] Fault ID
    # @param comment [String]  Comment text
    # @param user_id [Integer] User ID
    # @return [Hash] Created comment
    def create_fault_comment(id, comment, user_id:)
      @http.post("/api/v1/faults/#{id}/comments", {
        comment: comment,
        user_id: user_id
      })
    end

    # Get the audit-trail history for a fault.
    #
    # @param id [Integer] Fault ID
    # @return [Hash] { "history" => [...] }
    def get_fault_history(id)
      @http.get("/api/v1/faults/#{id}/history")
    end

    # -----------------------------------------------------------------------
    # Users
    # -----------------------------------------------------------------------

    # Get all users.
    #
    # @return [Hash] { "users" => [...] }
    def get_users
      @http.get("/api/v1/users")
    end

    private

    # Build the server context hash, merging defaults with per-call overrides.
    def build_server_context(override)
      base = @default_server || {}
      merged = base.merge(override || {})

      # Auto-populate hostname if not set
      merged[:hostname] ||= Socket.gethostname rescue nil

      return nil if merged.empty?

      merged
    end

    # Minimal URI-encoding for query parameter values.
    def uri_encode(str)
      URI.encode_www_form_component(str.to_s)
    end
  end
end

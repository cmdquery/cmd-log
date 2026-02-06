# frozen_string_literal: true

module CmdLog
  # Parses Ruby exception backtraces into the Honeybadger-compatible
  # BacktraceFrame format expected by POST /api/v1/notices.
  #
  # Ruby backtrace lines look like:
  #   /path/to/file.rb:42:in `method_name'
  #   /path/to/file.rb:42:in `block in method_name'
  #   /path/to/file.rb:42
  module BacktraceParser
    # Standard Ruby backtrace format:
    #   file:line:in `method'
    #   file:line:in `block (N levels) in method'
    #   file:line
    RUBY_FRAME_RE = /\A(.+):(\d+)(?::in\s+[`'](.+)')?\z/

    module_function

    # Parse a full backtrace array (as returned by Exception#backtrace) into
    # an array of frame hashes.
    #
    # @param backtrace [Array<String>, nil] The backtrace lines
    # @return [Array<Hash>] Array of { file:, line:, function: } hashes
    def parse(backtrace)
      return [] if backtrace.nil? || backtrace.empty?

      backtrace.filter_map { |line| parse_line(line) }
    end

    # Parse a single backtrace line into a frame hash.
    #
    # @param line [String] A backtrace line
    # @return [Hash, nil] { file:, line:, function: } or nil if unparseable
    def parse_line(line)
      match = RUBY_FRAME_RE.match(line.to_s.strip)
      return nil unless match

      {
        file: match[1],
        line: match[2].to_i,
        function: match[3] || ""
      }
    end
  end
end

# frozen_string_literal: true

require "test_helper"

class BacktraceParserTest < Minitest::Test
  def test_parses_standard_backtrace_line
    frames = CmdLog::BacktraceParser.parse([
      "/app/models/user.rb:42:in `save!'"
    ])

    assert_equal 1, frames.length
    assert_equal "/app/models/user.rb", frames[0][:file]
    assert_equal 42, frames[0][:line]
    assert_equal "save!", frames[0][:function]
  end

  def test_parses_line_without_method
    frames = CmdLog::BacktraceParser.parse([
      "/app/config/boot.rb:5"
    ])

    assert_equal 1, frames.length
    assert_equal "/app/config/boot.rb", frames[0][:file]
    assert_equal 5, frames[0][:line]
    assert_equal "", frames[0][:function]
  end

  def test_parses_block_in_method
    frames = CmdLog::BacktraceParser.parse([
      "/app/jobs/worker.rb:18:in `block in perform'"
    ])

    assert_equal 1, frames.length
    assert_equal "/app/jobs/worker.rb", frames[0][:file]
    assert_equal 18, frames[0][:line]
    assert_equal "block in perform", frames[0][:function]
  end

  def test_parses_block_with_levels
    frames = CmdLog::BacktraceParser.parse([
      "/app/jobs/worker.rb:18:in `block (2 levels) in perform'"
    ])

    assert_equal 1, frames.length
    assert_equal "block (2 levels) in perform", frames[0][:function]
  end

  def test_parses_multiple_lines
    bt = [
      "/app/models/user.rb:42:in `save!'",
      "/app/controllers/users_controller.rb:10:in `create'",
      "/app/config/boot.rb:5"
    ]
    frames = CmdLog::BacktraceParser.parse(bt)

    assert_equal 3, frames.length
    assert_equal "/app/models/user.rb", frames[0][:file]
    assert_equal "/app/controllers/users_controller.rb", frames[1][:file]
    assert_equal "/app/config/boot.rb", frames[2][:file]
  end

  def test_returns_empty_array_for_nil
    assert_equal [], CmdLog::BacktraceParser.parse(nil)
  end

  def test_returns_empty_array_for_empty
    assert_equal [], CmdLog::BacktraceParser.parse([])
  end

  def test_skips_unparseable_lines
    frames = CmdLog::BacktraceParser.parse([
      "this is not a backtrace line",
      "/app/models/user.rb:42:in `save!'"
    ])

    assert_equal 1, frames.length
    assert_equal "/app/models/user.rb", frames[0][:file]
  end

  def test_parse_line_returns_nil_for_garbage
    assert_nil CmdLog::BacktraceParser.parse_line("not a backtrace")
  end

  def test_parse_line_strips_whitespace
    frame = CmdLog::BacktraceParser.parse_line("  /app/foo.rb:1:in `bar'  ")

    assert_equal "/app/foo.rb", frame[:file]
    assert_equal 1, frame[:line]
    assert_equal "bar", frame[:function]
  end
end

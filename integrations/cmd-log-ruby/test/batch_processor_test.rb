# frozen_string_literal: true

require "test_helper"

class BatchProcessorTest < Minitest::Test
  def test_requires_flush_block
    assert_raises(ArgumentError) do
      CmdLog::BatchProcessor.new(batch_size: 5, batch_interval: 60)
    end
  end

  def test_push_accumulates_items
    flushed = []
    bp = CmdLog::BatchProcessor.new(batch_size: 100, batch_interval: 60) { |items| flushed.concat(items) }

    bp.push("a")
    bp.push("b")

    assert_equal 2, bp.size
    bp.shutdown
  end

  def test_auto_flushes_at_batch_size
    flushed = []
    bp = CmdLog::BatchProcessor.new(batch_size: 3, batch_interval: 60) { |items| flushed.concat(items) }

    bp.push("a")
    bp.push("b")
    bp.push("c")

    # Give the flush a moment to complete
    sleep(0.05)

    assert_equal %w[a b c], flushed
    assert_equal 0, bp.size
    bp.shutdown
  end

  def test_flush_drains_queue
    flushed = []
    bp = CmdLog::BatchProcessor.new(batch_size: 100, batch_interval: 60) { |items| flushed.concat(items) }

    bp.push("x")
    bp.push("y")
    bp.flush

    assert_equal %w[x y], flushed
    assert_equal 0, bp.size
    bp.shutdown
  end

  def test_flush_does_nothing_when_empty
    called = false
    bp = CmdLog::BatchProcessor.new(batch_size: 100, batch_interval: 60) { |_| called = true }

    bp.flush

    refute called
    bp.shutdown
  end

  def test_shutdown_flushes_remaining
    flushed = []
    bp = CmdLog::BatchProcessor.new(batch_size: 100, batch_interval: 60) { |items| flushed.concat(items) }

    bp.push("a")
    bp.push("b")
    bp.shutdown

    assert_equal %w[a b], flushed
  end

  def test_shutdown_stops_accepting_pushes
    flushed = []
    bp = CmdLog::BatchProcessor.new(batch_size: 100, batch_interval: 60) { |items| flushed.concat(items) }

    bp.shutdown
    bp.push("after-shutdown")

    assert_equal 0, bp.size
    assert_empty flushed
  end

  def test_stopped_returns_correct_state
    bp = CmdLog::BatchProcessor.new(batch_size: 100, batch_interval: 60) { |_| }

    refute bp.stopped?
    bp.shutdown
    assert bp.stopped?
  end

  def test_alias_shovel_operator
    flushed = []
    bp = CmdLog::BatchProcessor.new(batch_size: 100, batch_interval: 60) { |items| flushed.concat(items) }

    bp << "via-shovel"
    bp.flush

    assert_equal ["via-shovel"], flushed
    bp.shutdown
  end
end

# frozen_string_literal: true

module CmdLog
  # Thread-safe queue with automatic timer-based flushing.
  #
  # Accumulates items and flushes them in batches either when the batch size
  # threshold is reached or when the timer fires -- whichever comes first.
  #
  # The caller provides a flush callback that receives an Array of items.
  class BatchProcessor
    # @param batch_size    [Integer]  Flush when this many items are queued
    # @param batch_interval [Numeric] Seconds between automatic flushes
    # @param on_flush      [Proc]     Called with an Array of queued items
    def initialize(batch_size:, batch_interval:, &on_flush)
      raise ArgumentError, "on_flush block is required" unless on_flush

      @batch_size     = batch_size
      @batch_interval = batch_interval
      @on_flush       = on_flush
      @queue          = []
      @mutex          = Mutex.new
      @stopped        = false
      @timer_thread   = nil

      start_timer
    end

    # Add an item to the queue. Triggers an immediate flush if the batch size
    # threshold is reached.
    #
    # @param item [Object] The item to enqueue
    def push(item)
      should_flush = false

      @mutex.synchronize do
        return if @stopped

        @queue << item
        should_flush = @queue.size >= @batch_size
      end

      flush if should_flush
    end

    alias << push

    # Immediately flush all queued items (called from timer or manually).
    def flush
      items = nil

      @mutex.synchronize do
        return if @queue.empty?

        items = @queue.dup
        @queue.clear
      end

      @on_flush.call(items) if items && !items.empty?
    end

    # Stop the background timer, flush remaining items, and prevent further
    # pushes. Safe to call multiple times.
    def shutdown
      @mutex.synchronize { @stopped = true }
      stop_timer
      flush
    end

    # @return [Integer] Number of items currently queued
    def size
      @mutex.synchronize { @queue.size }
    end

    # @return [Boolean] Whether the processor has been shut down
    def stopped?
      @mutex.synchronize { @stopped }
    end

    private

    def start_timer
      @timer_thread = Thread.new do
        loop do
          sleep(@batch_interval)
          break if stopped?

          begin
            flush
          rescue => e
            # Swallow errors in the timer thread to prevent silent death
            $stderr.puts("CmdLog::BatchProcessor flush error: #{e.message}")
          end
        end
      end
      @timer_thread.abort_on_exception = false
    end

    def stop_timer
      return unless @timer_thread

      @timer_thread.kill
      @timer_thread.join(2) # Wait up to 2s for the thread to finish
      @timer_thread = nil
    end
  end
end

import type {
  LogEntry,
  LogClientConfig,
  LogLevel,
  QueuedLog,
  BatchLogResponse,
  LogResponse,
} from './types';

/**
 * Client for sending logs to the cmd-log ingestion service
 * 
 * Features:
 * - Automatic batching for efficient log transmission
 * - Retry logic with exponential backoff
 * - Rate limit handling
 * - Queue management
 * - Works in both browser and Node.js environments
 */
export class LogClient {
  private config: Required<LogClientConfig>;
  private queue: QueuedLog[] = [];
  private batchTimer: ReturnType<typeof setInterval> | null = null;
  private isProcessing = false;
  private failedLogs: QueuedLog[] = [];

  constructor(config: LogClientConfig) {
    this.config = {
      enableBatching: true,
      batchSize: 10,
      batchInterval: 5000, // 5 seconds
      maxRetries: 3,
      retryDelay: 1000, // 1 second
      onError: (error) => console.error('Log client error:', error),
      ...config,
    };

    // Validate required config
    if (!this.config.apiUrl) {
      throw new Error('apiUrl is required');
    }
    if (!this.config.apiKey) {
      throw new Error('apiKey is required');
    }
    if (!this.config.service) {
      throw new Error('service is required');
    }

    // Start batch processing if enabled
    if (this.config.enableBatching) {
      this.startBatchProcessor();
    }

    // Handle page unload to flush remaining logs (browser only)
    if (typeof window !== 'undefined') {
      window.addEventListener('beforeunload', () => {
        this.flush();
      });
    }
  }

  /**
   * Create a log entry with automatic timestamp
   */
  private createLogEntry(
    level: LogLevel,
    message: string,
    metadata?: Record<string, unknown>
  ): LogEntry {
    const entry: LogEntry = {
      timestamp: new Date().toISOString(),
      service: this.config.service,
      level,
      message,
      metadata: metadata ? { ...metadata } : undefined,
    };

    // Add browser-specific metadata if available
    if (typeof window !== 'undefined') {
      entry.metadata = {
        ...entry.metadata,
        userAgent: navigator.userAgent,
        url: window.location.href,
        referrer: document.referrer,
      };
    }

    return entry;
  }

  /**
   * Send a single log entry
   */
  async log(
    level: LogLevel,
    message: string,
    metadata?: Record<string, unknown>
  ): Promise<void> {
    const entry = this.createLogEntry(level, message, metadata);

    if (this.config.enableBatching) {
      this.queueLog(entry);
    } else {
      await this.sendLog(entry);
    }
  }

  /**
   * Convenience methods for different log levels
   */
  debug(message: string, metadata?: Record<string, unknown>): Promise<void> {
    return this.log('DEBUG', message, metadata);
  }

  info(message: string, metadata?: Record<string, unknown>): Promise<void> {
    return this.log('INFO', message, metadata);
  }

  warn(message: string, metadata?: Record<string, unknown>): Promise<void> {
    return this.log('WARN', message, metadata);
  }

  error(message: string, metadata?: Record<string, unknown>): Promise<void> {
    return this.log('ERROR', message, metadata);
  }

  fatal(message: string, metadata?: Record<string, unknown>): Promise<void> {
    return this.log('FATAL', message, metadata);
  }

  /**
   * Send a log entry directly (no batching)
   */
  async sendLog(entry: LogEntry, retries = 0): Promise<void> {
    try {
      const response = await this.fetchWithRetry(
        `${this.config.apiUrl}/api/v1/logs`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-API-Key': this.config.apiKey,
          },
          body: JSON.stringify({ log: entry }),
        },
        retries
      );

      if (!response.ok) {
        if (response.status === 429) {
          // Rate limited - add to queue for retry
          this.queueLog(entry, retries);
          return;
        }

        const errorData = await response.json().catch(() => ({}));
        throw new Error(
          `Log ingestion failed: ${response.status} ${response.statusText} - ${errorData.error || 'Unknown error'}`
        );
      }

      await response.json() as LogResponse;
    } catch (error) {
      const err = error instanceof Error ? error : new Error(String(error));

      if (retries < this.config.maxRetries) {
        // Exponential backoff
        const delay = this.config.retryDelay * Math.pow(2, retries);
        await this.delay(delay);
        return this.sendLog(entry, retries + 1);
      }

      // Max retries reached
      this.config.onError(err);
      this.failedLogs.push({
        entry,
        retries: retries + 1,
        timestamp: Date.now(),
      });
      throw err;
    }
  }

  /**
   * Queue a log entry for batch processing
   */
  private queueLog(entry: LogEntry, retries = 0): void {
    this.queue.push({
      entry,
      retries,
      timestamp: Date.now(),
    });

    // Flush immediately if batch size is reached
    if (this.queue.length >= this.config.batchSize) {
      this.flush();
    }
  }

  /**
   * Send batched logs
   */
  async sendBatch(logs: LogEntry[]): Promise<void> {
    if (logs.length === 0) return;

    try {
      const response = await fetch(`${this.config.apiUrl}/api/v1/logs/batch`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': this.config.apiKey,
        },
        body: JSON.stringify({ logs }),
      });

      if (!response.ok) {
        if (response.status === 429) {
          // Rate limited - requeue logs
          logs.forEach((log) => this.queueLog(log));
          return;
        }

        const errorData = await response.json().catch(() => ({}));
        throw new Error(
          `Batch log ingestion failed: ${response.status} ${response.statusText} - ${errorData.error || 'Unknown error'}`
        );
      }

      const data: BatchLogResponse = await response.json();

      // Handle partial failures
      if (data.errors && data.errors.length > 0) {
        console.warn('Some logs were rejected:', data.errors);
      }
    } catch (error) {
      const err = error instanceof Error ? error : new Error(String(error));

      // Retry individual logs
      logs.forEach((log) => {
        const queuedLog = this.queue.find((q) => q.entry === log);
        if (queuedLog && queuedLog.retries < this.config.maxRetries) {
          queuedLog.retries++;
          this.queueLog(log, queuedLog.retries);
        } else {
          this.config.onError(err);
        }
      });
    }
  }

  /**
   * Start the batch processor
   */
  private startBatchProcessor(): void {
    // Use setInterval with proper typing for both Node.js and browser
    this.batchTimer = setInterval(() => {
      if (this.queue.length > 0 && !this.isProcessing) {
        this.flush();
      }
    }, this.config.batchInterval) as unknown as ReturnType<typeof setInterval>;
  }

  /**
   * Flush all queued logs
   */
  async flush(): Promise<void> {
    if (this.isProcessing || this.queue.length === 0) return;

    this.isProcessing = true;
    const logsToSend = this.queue.splice(0, this.config.batchSize);
    const entries = logsToSend.map((q) => q.entry);

    try {
      await this.sendBatch(entries);
    } finally {
      this.isProcessing = false;
    }
  }

  /**
   * Get failed logs for manual retry
   */
  getFailedLogs(): QueuedLog[] {
    return [...this.failedLogs];
  }

  /**
   * Retry failed logs
   */
  async retryFailedLogs(): Promise<void> {
    const failed = this.failedLogs.splice(0);
    for (const queuedLog of failed) {
      await this.sendLog(queuedLog.entry, queuedLog.retries);
    }
  }

  /**
   * Destroy the client and flush remaining logs
   */
  async destroy(): Promise<void> {
    if (this.batchTimer) {
      clearInterval(this.batchTimer);
      this.batchTimer = null;
    }
    await this.flush();
  }

  /**
   * Helper method for fetch with retry logic
   */
  private async fetchWithRetry(
    url: string,
    options: RequestInit,
    retries: number
  ): Promise<Response> {
    try {
      // Use global fetch (available in both Node.js 18+ and browsers)
      return await fetch(url, options);
    } catch (error) {
      if (retries < this.config.maxRetries) {
        const delay = this.config.retryDelay * Math.pow(2, retries);
        await this.delay(delay);
        return this.fetchWithRetry(url, options, retries + 1);
      }
      throw error;
    }
  }

  /**
   * Helper method for delay/promise sleep
   */
  private delay(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}


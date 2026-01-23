/**
 * Log level types supported by the cmd-log ingestion service
 */
export type LogLevel = 'DEBUG' | 'INFO' | 'WARN' | 'WARNING' | 'ERROR' | 'FATAL' | 'CRITICAL';

/**
 * A single log entry
 */
export interface LogEntry {
  timestamp: string; // ISO 8601 format
  service: string;
  level: LogLevel;
  message: string;
  metadata?: Record<string, unknown>;
}

/**
 * Single log ingestion request
 */
export interface LogRequest {
  log: LogEntry;
}

/**
 * Batch log ingestion request
 */
export interface BatchLogRequest {
  logs: LogEntry[];
}

/**
 * Single log ingestion response
 */
export interface LogResponse {
  message: string;
}

/**
 * Batch log ingestion response
 */
export interface BatchLogResponse {
  message: string;
  accepted: number;
  total: number;
  errors?: string[];
  rejected?: number;
}

/**
 * Configuration options for the LogClient
 */
export interface LogClientConfig {
  /** API URL of the log ingestion service */
  apiUrl: string;
  /** API key for authentication */
  apiKey: string;
  /** Service name to use for logs */
  service: string;
  /** Enable automatic batching (default: true) */
  enableBatching?: boolean;
  /** Maximum number of logs to batch before sending (default: 10) */
  batchSize?: number;
  /** Interval in milliseconds to flush batched logs (default: 5000) */
  batchInterval?: number;
  /** Maximum number of retries for failed requests (default: 3) */
  maxRetries?: number;
  /** Base delay in milliseconds for retry exponential backoff (default: 1000) */
  retryDelay?: number;
  /** Error callback function */
  onError?: (error: Error) => void;
}

/**
 * Internal representation of a queued log entry
 */
export interface QueuedLog {
  entry: LogEntry;
  retries: number;
  timestamp: number;
}




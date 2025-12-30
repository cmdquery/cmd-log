/**
 * @cmd-log/client
 * 
 * Client library for sending logs to the cmd-log ingestion service.
 * 
 * Features:
 * - Automatic batching for efficient log transmission
 * - Retry logic with exponential backoff
 * - Rate limit handling
 * - Queue management
 * - Works in both browser and Node.js environments
 * 
 * @example
 * ```typescript
 * import { LogClient } from '@cmd-log/client';
 * 
 * const client = new LogClient({
 *   apiUrl: 'https://your-service.com',
 *   apiKey: 'your-api-key',
 *   service: 'my-service',
 * });
 * 
 * await client.info('Application started');
 * await client.error('Something went wrong', { error: 'details' });
 * ```
 */

export { LogClient } from './client';
export type {
  LogLevel,
  LogEntry,
  LogRequest,
  BatchLogRequest,
  LogResponse,
  BatchLogResponse,
  LogClientConfig,
  QueuedLog,
} from './types';
export { createLogEntry, validateLogEntry } from './utils';


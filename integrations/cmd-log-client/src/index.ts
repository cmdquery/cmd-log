/**
 * @cmd-log/client
 *
 * Client library for the cmd-log service.
 *
 * - **LogClient** -- send structured logs (batching, retries, rate-limit handling)
 * - **NotifierClient** -- report errors and manage faults (Honeybadger-compatible)
 *
 * Works in both browser and Node.js (18+) environments.
 *
 * @example
 * ```typescript
 * import { LogClient, NotifierClient } from '@cmdquery/log-ingestion-next';
 *
 * const logs = new LogClient({
 *   apiUrl: 'https://your-service.com',
 *   apiKey: 'your-api-key',
 *   service: 'my-service',
 * });
 *
 * await logs.info('Application started');
 *
 * const notifier = new NotifierClient({
 *   apiUrl: 'https://your-service.com',
 *   apiKey: 'your-api-key',
 * });
 *
 * try { dangerousWork(); }
 * catch (err) { await notifier.notify(err as Error); }
 * ```
 */

// Log client
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

// Notifier / fault-tracking client
export { NotifierClient } from './notifier';
export type {
  BacktraceFrame,
  Breadcrumb,
  NoticeRequest,
  NoticeResponse,
  NotifyOptions,
  Fault,
  Notice,
  Comment,
  FaultHistory,
  User,
  FaultListResponse,
  NoticesResponse,
  CommentsResponse,
  HistoryResponse,
  UsersResponse,
  MessageResponse,
  NotifierClientConfig,
} from './notifier-types';




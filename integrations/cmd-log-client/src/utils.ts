import type { LogEntry, LogLevel } from './types';

/**
 * Create a log entry with the current timestamp
 */
export function createLogEntry(
  service: string,
  level: LogLevel,
  message: string,
  metadata?: Record<string, unknown>
): LogEntry {
  return {
    timestamp: new Date().toISOString(),
    service,
    level,
    message,
    metadata,
  };
}

/**
 * Validate a log entry
 */
export function validateLogEntry(entry: LogEntry): boolean {
  if (!entry.timestamp || !entry.service || !entry.level || !entry.message) {
    return false;
  }

  // Validate timestamp is ISO 8601 format
  const timestampRegex = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{3})?Z?$/;
  if (!timestampRegex.test(entry.timestamp)) {
    return false;
  }

  // Validate log level
  const validLevels: LogLevel[] = ['DEBUG', 'INFO', 'WARN', 'WARNING', 'ERROR', 'FATAL', 'CRITICAL'];
  if (!validLevels.includes(entry.level)) {
    return false;
  }

  return true;
}


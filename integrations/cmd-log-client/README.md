# @cmdquery/log-ingestion-next

Client library for log ingestion and error tracking with the [cmd-log](https://github.com/cmdquery/cmd-log) service. Works in both browser and Node.js environments.

## Features

- **Log Ingestion** - Send structured logs with automatic batching
- **Error Tracking** - Report errors with stack traces (Honeybadger-compatible)
- **Fault Management** - List, resolve, ignore, assign, tag, and merge faults
- **Retry Logic** - Exponential backoff for failed requests
- **Rate Limit Handling** - Automatic handling of 429 responses
- **Queue Management** - In-memory queue for batched logs
- **TypeScript** - Full type definitions included
- **Universal** - Works with React, Next.js, Node.js, and more

## Installation

```bash
npm install @cmdquery/log-ingestion-next
```

## Quick Start

### Logging

```typescript
import { LogClient } from '@cmdquery/log-ingestion-next';

const logger = new LogClient({
  apiUrl: 'https://your-service.com',
  apiKey: 'your-api-key',
  service: 'my-service',
});

await logger.info('Application started');
await logger.error('Something went wrong', { error: 'details' });
await logger.debug('Debug information', { userId: '123' });
```

### Error Tracking

```typescript
import { NotifierClient } from '@cmdquery/log-ingestion-next';

const notifier = new NotifierClient({
  apiUrl: 'https://your-service.com',
  apiKey: 'your-api-key',
});

try {
  dangerousWork();
} catch (err) {
  await notifier.notify(err as Error);
}
```

---

## LogClient

### Configuration

```typescript
const logger = new LogClient({
  apiUrl: 'https://your-service.com',      // Required
  apiKey: 'your-api-key',                  // Required
  service: 'my-service',                   // Required
  enableBatching: true,                    // Default: true
  batchSize: 10,                           // Max logs per batch (default: 10)
  batchInterval: 5000,                     // Flush interval in ms (default: 5000)
  maxRetries: 3,                           // Max retry attempts (default: 3)
  retryDelay: 1000,                        // Base retry delay in ms (default: 1000)
  onError: (error) => {                    // Error callback
    console.error('Log error:', error);
  },
});
```

### Log Levels

```typescript
await logger.debug('Debug message');
await logger.info('Info message');
await logger.warn('Warning message');
await logger.error('Error message');
await logger.fatal('Fatal error');
```

### Metadata

```typescript
await logger.info('User logged in', {
  userId: '123',
  email: 'user@example.com',
});
```

### Manual Flush & Cleanup

```typescript
// Flush queued logs immediately
await logger.flush();

// Destroy client and flush remaining logs
await logger.destroy();
```

### Send a Log Directly (No Batching)

```typescript
import { LogClient, createLogEntry } from '@cmdquery/log-ingestion-next';

const entry = createLogEntry('my-service', 'INFO', 'Direct log');
await logger.sendLog(entry);
```

### Methods

| Method | Description |
| --- | --- |
| `log(level, message, metadata?)` | Send a log at the given level |
| `debug(message, metadata?)` | Send a DEBUG log |
| `info(message, metadata?)` | Send an INFO log |
| `warn(message, metadata?)` | Send a WARN log |
| `error(message, metadata?)` | Send an ERROR log |
| `fatal(message, metadata?)` | Send a FATAL log |
| `sendLog(entry)` | Send a log entry directly (no batching) |
| `flush()` | Flush the queue immediately |
| `destroy()` | Flush remaining logs and tear down the client |
| `getFailedLogs()` | Retrieve logs that failed to send |
| `retryFailedLogs()` | Retry all failed logs |

---

## NotifierClient

The `NotifierClient` provides error reporting and full fault management. Errors are sent as Honeybadger-compatible notices and automatically grouped into faults by the server.

### Configuration

```typescript
const notifier = new NotifierClient({
  apiUrl: 'https://your-service.com',       // Required
  apiKey: 'your-api-key',                   // Required
  notifier: {                               // Override notifier metadata
    name: 'my-app',
    version: '1.0.0',
    url: 'https://github.com/my/app',
  },
  defaultServer: {                          // Sent with every notice
    environment_name: 'production',
    hostname: 'web-01',
    revision: 'abc123',
  },
  defaultContext: {                          // Merged into request.context
    region: 'us-east-1',
  },
  onError: (error) => {
    console.error('Notifier error:', error);
  },
});
```

### Notify with Extra Context

```typescript
await notifier.notify(err as Error, {
  errorClass: 'PaymentError',
  context: { userId: '42', plan: 'pro' },
  request: {
    url: '/api/checkout',
    component: 'PaymentController',
    action: 'create',
    params: { amount: 100 },
  },
  server: {
    environment_name: 'production',
    revision: 'abc123',
  },
  breadcrumbs: {
    enabled: true,
    trail: [
      { category: 'navigation', message: 'Visited /checkout', time: new Date().toISOString() },
    ],
  },
});
```

### Send a Raw Notice

```typescript
import type { NoticeRequest } from '@cmdquery/log-ingestion-next';

const notice: NoticeRequest = {
  notifier: { name: 'my-app', version: '1.0.0', url: '' },
  error: {
    class: 'TypeError',
    message: 'Cannot read property x of undefined',
    backtrace: [
      { file: 'src/index.ts', line: 42, function: 'handleRequest' },
    ],
  },
};

const { id, fault_id } = await notifier.sendNotice(notice);
```

### Fault Management

```typescript
// List faults (with optional search and pagination)
const { faults, total } = await notifier.listFaults('TypeError', 20, 0);

// Get / update / delete a fault
const fault = await notifier.getFault(42);
await notifier.updateFault(42, { environment: 'staging' });
await notifier.deleteFault(42);
```

### Fault Actions

```typescript
await notifier.resolveFault(42);
await notifier.unresolveFault(42);
await notifier.ignoreFault(42);

// Assign to a user (pass null to unassign)
await notifier.assignFault(42, 7);
await notifier.assignFault(42, null);

// Tags
await notifier.addFaultTags(42, ['critical', 'payments']);
await notifier.replaceFaultTags(42, ['low-priority']);

// Merge fault 42 into fault 99
await notifier.mergeFaults(42, 99);
```

### Fault Sub-Resources

```typescript
const { notices } = await notifier.getFaultNotices(42, 10, 0);
const stats = await notifier.getFaultStats(42);
const { comments } = await notifier.getFaultComments(42);
await notifier.createFaultComment(42, 'Looking into this', 7);
const { history } = await notifier.getFaultHistory(42);
const { users } = await notifier.getUsers();
```

### Notice Methods

| Method | Description |
| --- | --- |
| `notify(error, options?)` | Report an `Error` or string |
| `sendNotice(notice)` | Send a raw `NoticeRequest` |

### Fault CRUD

| Method | Description |
| --- | --- |
| `listFaults(query?, limit?, offset?)` | List faults with optional search |
| `getFault(id)` | Get a single fault |
| `updateFault(id, updates)` | Update a fault |
| `deleteFault(id)` | Delete a fault |

### Fault Actions Reference

| Method | Description |
| --- | --- |
| `resolveFault(id)` | Mark a fault as resolved |
| `unresolveFault(id)` | Re-open a resolved fault |
| `ignoreFault(id)` | Ignore a fault |
| `assignFault(id, userId)` | Assign (or unassign with `null`) a fault |
| `addFaultTags(id, tags)` | Append tags to a fault |
| `replaceFaultTags(id, tags)` | Replace all tags on a fault |
| `mergeFaults(sourceId, targetId)` | Merge two faults |

### Sub-Resource Methods

| Method | Description |
| --- | --- |
| `getFaultNotices(id, limit?, offset?)` | List error occurrences for a fault |
| `getFaultStats(id)` | Get fault statistics |
| `getFaultComments(id)` | List comments on a fault |
| `createFaultComment(id, comment, userId)` | Add a comment |
| `getFaultHistory(id)` | Get audit history |
| `getUsers()` | List users |

---

## Types

All types are exported from the package and available for import:

```typescript
import type {
  // Logging
  LogLevel,
  LogEntry,
  LogClientConfig,
  QueuedLog,

  // Error tracking
  NoticeRequest,
  NoticeResponse,
  NotifyOptions,
  Fault,
  Notice,
  NotifierClientConfig,
} from '@cmdquery/log-ingestion-next';
```

## Requirements

- Node.js >= 18

## License

MIT

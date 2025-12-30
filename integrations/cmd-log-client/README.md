# @cmdquery/log-ingestion-next

Client library for sending logs to the cmd-log ingestion service. Works in both browser and Node.js environments.

## Features

- ✅ **Automatic Batching** - Efficiently batch logs before sending
- ✅ **Retry Logic** - Exponential backoff for failed requests
- ✅ **Rate Limit Handling** - Automatic handling of 429 responses
- ✅ **Queue Management** - In-memory queue for batched logs
- ✅ **TypeScript Support** - Full type definitions included
- ✅ **Framework Agnostic** - Works with React, Next.js, Node.js, and more
- ✅ **Browser & Node.js** - Universal compatibility

## Installation

### From GitHub Packages

This package is published to GitHub Packages as a private package. To install it:

1. **Create a GitHub Personal Access Token** with `read:packages` permission
2. **Configure npm to use GitHub Packages** for the `@cmdquery` scope

Create or edit `.npmrc` in your project root (or `~/.npmrc` for global):

```ini
@cmdquery:registry=https://npm.pkg.github.com
//npm.pkg.github.com/:_authToken=${GITHUB_TOKEN}
```

Set the `GITHUB_TOKEN` environment variable:

```bash
export GITHUB_TOKEN=your_github_token_here
```

Or add it directly to `.npmrc` (less secure):

```ini
@cmdquery:registry=https://npm.pkg.github.com
//npm.pkg.github.com/:_authToken=ghp_your_token_here
```

3. **Install the package**:

```bash
npm install @cmdquery/log-ingestion-next
```

Or with yarn:

```bash
yarn add @cmd-log/client
```

## Usage

### Basic Usage

```typescript
import { LogClient } from '@cmdquery/log-ingestion-next';

const client = new LogClient({
  apiUrl: 'https://your-service.com',
  apiKey: 'your-api-key',
  service: 'my-service',
});

// Send logs
await client.info('Application started');
await client.error('Something went wrong', { error: 'details' });
await client.debug('Debug information', { userId: '123' });
```

### Configuration Options

```typescript
const client = new LogClient({
  apiUrl: 'https://your-service.com',      // Required: API URL
  apiKey: 'your-api-key',                  // Required: API key
  service: 'my-service',                    // Required: Service name
  enableBatching: true,                    // Enable batching (default: true)
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
await client.debug('Debug message');
await client.info('Info message');
await client.warn('Warning message');
await client.error('Error message');
await client.fatal('Fatal error');
```

### With Metadata

```typescript
await client.info('User logged in', {
  userId: '123',
  email: 'user@example.com',
  timestamp: new Date().toISOString(),
});
```

### Manual Flush

```typescript
// Flush queued logs immediately
await client.flush();
```

### Send Log Directly (No Batching)

```typescript
import { LogClient, createLogEntry } from '@cmdquery/log-ingestion-next';

const entry = createLogEntry('my-service', 'INFO', 'Direct log');
await client.sendLog(entry);
```

### Cleanup

```typescript
// Destroy client and flush remaining logs
await client.destroy();
```

## API Reference

### LogClient

Main client class for sending logs.

#### Constructor

```typescript
new LogClient(config: LogClientConfig)
```

#### Methods

- `log(level: LogLevel, message: string, metadata?: Record<string, unknown>): Promise<void>`
- `debug(message: string, metadata?: Record<string, unknown>): Promise<void>`
- `info(message: string, metadata?: Record<string, unknown>): Promise<void>`
- `warn(message: string, metadata?: Record<string, unknown>): Promise<void>`
- `error(message: string, metadata?: Record<string, unknown>): Promise<void>`
- `fatal(message: string, metadata?: Record<string, unknown>): Promise<void>`
- `sendLog(entry: LogEntry): Promise<void>` - Send log directly without batching
- `flush(): Promise<void>` - Flush queued logs
- `destroy(): Promise<void>` - Destroy client and flush remaining logs
- `getFailedLogs(): QueuedLog[]` - Get logs that failed to send
- `retryFailedLogs(): Promise<void>` - Retry failed logs

### Types

```typescript
type LogLevel = 'DEBUG' | 'INFO' | 'WARN' | 'WARNING' | 'ERROR' | 'FATAL' | 'CRITICAL';

interface LogEntry {
  timestamp: string;      // ISO 8601 format
  service: string;
  level: LogLevel;
  message: string;
  metadata?: Record<string, unknown>;
}

interface LogClientConfig {
  apiUrl: string;
  apiKey: string;
  service: string;
  enableBatching?: boolean;
  batchSize?: number;
  batchInterval?: number;
  maxRetries?: number;
  retryDelay?: number;
  onError?: (error: Error) => void;
}
```

## Publishing

This package is configured to publish to GitHub Packages. To publish a new version:

1. **Create a GitHub Personal Access Token** with `write:packages` permission
2. **Set the token** as `GITHUB_TOKEN` environment variable
3. **Update version** in `package.json`
4. **Build the package**:
   ```bash
   npm run build
   ```
5. **Publish**:
   ```bash
   npm publish
   ```

The package will be published to: `https://npm.pkg.github.com/@cmdquery/log-ingestion-next`

## Examples

### React/Next.js

```typescript
import { LogClient } from '@cmdquery/log-ingestion-next';

const client = new LogClient({
  apiUrl: process.env.NEXT_PUBLIC_LOG_INGESTION_URL!,
  apiKey: process.env.NEXT_PUBLIC_LOG_INGESTION_API_KEY!,
  service: 'nextjs-app',
});

// In a component
function MyComponent() {
  useEffect(() => {
    client.info('Component mounted');
  }, []);
  
  return <div>...</div>;
}
```

### Node.js

```typescript
import { LogClient } from '@cmdquery/log-ingestion-next';

const client = new LogClient({
  apiUrl: process.env.LOG_INGESTION_URL!,
  apiKey: process.env.LOG_INGESTION_API_KEY!,
  service: 'nodejs-service',
});

// In your application
app.get('/api/users', async (req, res) => {
  try {
    client.info('Fetching users');
    const users = await getUsers();
    client.info('Users fetched', { count: users.length });
    res.json(users);
  } catch (error) {
    client.error('Failed to fetch users', { error: error.message });
    res.status(500).json({ error: 'Internal server error' });
  }
});
```

## License

MIT


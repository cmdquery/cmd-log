# cmd-log

A high-performance log ingestion and error tracking service built in Go. Collects, validates, and stores structured logs while providing Honeybadger-compatible error tracking with automatic fault grouping, an admin dashboard, and a TypeScript client SDK.

## Features

- **Log Ingestion** — REST API for single and batch log ingestion with JSON and plain text support
- **Error Tracking** — Honeybadger-compatible notice ingestion with automatic fault grouping and fingerprinting
- **Fault Management** — Resolve, ignore, assign, merge, tag, and comment on faults
- **Admin Dashboard** — Vue.js SPA with dark mode for viewing errors, logs, metrics, and managing API keys
- **Authentication** — API key-based auth for ingestion, cookie-based sessions for the admin panel
- **Rate Limiting** — Per-API-key rate limiting to prevent abuse
- **Batch Processing** — Configurable batching for high-throughput ingestion
- **Time-Series Storage** — TimescaleDB hypertables optimized for time-series queries
- **TypeScript Client SDK** — `@cmdquery/log-ingestion-next` with automatic batching, retries, and rate limit handling

## Tech Stack

| Layer          | Technology                          |
|----------------|-------------------------------------|
| Backend        | Go 1.21+ / Gin                      |
| Frontend       | Vue.js 3 / Vite                     |
| Database       | TimescaleDB (PostgreSQL)             |
| Infrastructure | Docker / Docker Compose              |
| Client SDK     | TypeScript (browser + Node.js)       |

## Prerequisites

- **Go 1.21 or later** — [Download Go](https://golang.org/dl/)
- **Node.js 18 or later** — [Download Node.js](https://nodejs.org/) (for building the frontend)
- **Docker Desktop** (macOS/Windows) or **Docker Engine** (Linux) — [Download Docker](https://www.docker.com/products/docker-desktop)
- **Docker Compose** — usually included with Docker Desktop

Verify Docker is installed and running:

```bash
docker --version
make docker-check
```

## Quick Start

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd cmd-log
   ```

2. **Start TimescaleDB**:
   ```bash
   make docker-up
   ```

3. **Run database migrations**:
   ```bash
   make migrate
   ```

4. **Configure environment variables** (optional):
   ```bash
   make env
   ```
   Edit `.env` with your settings. If you skip this step, defaults are used.

5. **Build and run**:
   ```bash
   make build
   ./bin/server
   ```
   Or run directly in development:
   ```bash
   make run
   ```

6. **Verify the service is running**:
   ```bash
   curl http://localhost:8080/health
   ```

The admin dashboard is served at `http://localhost:8080` once the frontend is built.

## Configuration

Configuration is provided via environment variables (prefixed with `LOG_INGESTION_`) or a `config.yaml` file.

### Server

| Variable | Description | Default |
|---|---|---|
| `LOG_INGESTION_SERVER_PORT` | Server port | `8080` |
| `LOG_INGESTION_SERVER_HOST` | Server host | `0.0.0.0` |

### Database

| Variable | Description | Default |
|---|---|---|
| `LOG_INGESTION_DB_HOST` | Database host | `localhost` |
| `LOG_INGESTION_DB_PORT` | Database port | `5432` |
| `LOG_INGESTION_DB_USER` | Database user | `postgres` |
| `LOG_INGESTION_DB_PASSWORD` | Database password | `postgres` |
| `LOG_INGESTION_DB_NAME` | Database name | `logs` |
| `LOG_INGESTION_DB_SSLMODE` | SSL mode | `disable` |

### Batch Processing

| Variable | Description | Default |
|---|---|---|
| `LOG_INGESTION_BATCH_SIZE` | Batch size for log ingestion | `1000` |
| `LOG_INGESTION_BATCH_FLUSH_INTERVAL` | Flush interval | `5s` |

### Rate Limiting

| Variable | Description | Default |
|---|---|---|
| `LOG_INGESTION_RATELIMIT_ENABLED` | Enable rate limiting | `true` |
| `LOG_INGESTION_RATELIMIT_DEFAULT_RPS` | Default requests per second | `100` |
| `LOG_INGESTION_RATELIMIT_BURST` | Burst size | `200` |

### Authentication

| Variable | Description | Default |
|---|---|---|
| `LOG_INGESTION_API_KEYS` | Comma-separated API keys for log ingestion | — |
| `LOG_INGESTION_ADMIN_API_KEYS` | Comma-separated admin API keys (falls back to `LOG_INGESTION_API_KEYS`) | — |

## API Overview

All endpoints except `/health` and `/admin/login` require authentication via `X-API-Key` header or `Authorization: Bearer` token.

### Health

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/health` | Service health check (no auth) |

### Log Ingestion

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/v1/logs` | Ingest a single log entry |
| `POST` | `/api/v1/logs/batch` | Ingest a batch of log entries |

### Error Notices

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/v1/notices` | Ingest an error notice (Honeybadger-compatible) |

### Faults

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/v1/faults` | List faults with search and filtering |
| `GET` | `/api/v1/faults/:id` | Get fault details |
| `PATCH` | `/api/v1/faults/:id` | Update a fault |
| `DELETE` | `/api/v1/faults/:id` | Delete a fault |
| `POST` | `/api/v1/faults/:id/resolve` | Resolve a fault |
| `POST` | `/api/v1/faults/:id/unresolve` | Unresolve a fault |
| `POST` | `/api/v1/faults/:id/ignore` | Ignore a fault |
| `POST` | `/api/v1/faults/:id/assign` | Assign a fault to a user |
| `POST` | `/api/v1/faults/:id/tags` | Add tags to a fault |
| `PUT` | `/api/v1/faults/:id/tags` | Replace fault tags |
| `POST` | `/api/v1/faults/:id/merge` | Merge faults |
| `GET` | `/api/v1/faults/:id/notices` | Get fault occurrences |
| `GET` | `/api/v1/faults/:id/stats` | Get fault statistics |
| `GET` | `/api/v1/faults/:id/comments` | Get fault comments |
| `POST` | `/api/v1/faults/:id/comments` | Create a comment |
| `GET` | `/api/v1/faults/:id/history` | Get fault history |
| `GET` | `/api/v1/users` | List users |

### Admin

Admin endpoints use cookie-based session authentication. Log in via `POST /admin/login` first.

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/admin/login` | Admin login (no auth) |
| `GET` | `/admin/health` | Detailed health status |
| `GET` | `/admin/metrics` | Service metrics |
| `GET` | `/admin/logs/recent` | Recent log entries |
| `GET` | `/admin/logs/:id` | Get a log by ID |
| `GET` | `/admin/stats` | Aggregated statistics |
| `GET` | `/admin/api/keys` | List API keys |
| `POST` | `/admin/api/keys` | Create an API key |
| `DELETE` | `/admin/api/keys/:id` | Delete an API key |

## Error Tracking

cmd-log provides Honeybadger-compatible error tracking. When a notice is ingested via `POST /api/v1/notices`, the service:

1. Extracts the error class, message, and location from the notice payload.
2. Generates a fingerprint from the error class, location, and environment.
3. Matches it against existing faults — if a matching fault exists, it increments the occurrence count; otherwise it creates a new fault.
4. Stores the full notice (including backtrace, request context, and server info) linked to the fault.

### Fault Lifecycle

- **Open** — new or recurring faults that need attention.
- **Resolved** — faults marked as fixed. If a new notice matches a resolved fault, it reopens automatically.
- **Ignored** — faults intentionally dismissed.

Faults can also be assigned to users, tagged, commented on, and merged with other faults. A full history of state changes is tracked.

## Admin Dashboard

The Vue.js admin dashboard is served from the root URL and provides:

- **Error Viewer** — browse, search, and filter faults; view individual fault details with backtrace and breadcrumbs
- **Log Viewer** — browse recent log entries with filtering
- **Metrics** — service health and performance metrics
- **API Key Management** — create and revoke API keys

Access the dashboard at `http://localhost:8080` after building the frontend and starting the server.

## Client SDK

The TypeScript client library [`@cmdquery/log-ingestion-next`](integrations/cmd-log-client/) works in both browser and Node.js environments.

```typescript
import { LogClient } from '@cmdquery/log-ingestion-next';

const client = new LogClient({
  apiUrl: 'https://your-service.com',
  apiKey: 'your-api-key',
  service: 'my-service',
});

await client.info('Application started');
await client.error('Something went wrong', { userId: '123' });

// Flush remaining logs on shutdown
await client.destroy();
```

Key features: automatic batching, retry with exponential backoff, rate limit handling, and queue management for failed logs.

See the [SDK README](integrations/cmd-log-client/README.md) for full documentation.

## Integration Guides

- [React / Next.js](integrations/react-nextjs.md)
- [Node.js](integrations/nodejs.md)
- [Ruby on Rails](integrations/ruby-on-rails.md)

## Deployment

Multiple deployment options are available:

- **Docker Compose (development)** — `docker-compose.yml` includes a TimescaleDB container
- **Docker Compose (production)** — `docker-compose.prod.yml` connects to an external managed database
- **systemd** — service files and setup scripts in `deploy/`
- **DigitalOcean** — automated deployment via `make deploy`

See [DEPLOYMENT.md](DEPLOYMENT.md) for the full guide and [DEPLOY_DIGITALOCEAN.md](DEPLOY_DIGITALOCEAN.md) for DigitalOcean-specific instructions.

### Deployment Make Targets

```bash
make deploy          # Interactive deployment to a DigitalOcean droplet
make deploy-quick    # Quick deploy using DROPLET_IP and DROPLET_USER env vars
make deploy-status   # Check remote deployment status
make deploy-logs     # Tail remote deployment logs
```

## Database Schema

The service uses TimescaleDB with the following tables:

| Table | Purpose |
|---|---|
| `logs` | Time-series log entries (TimescaleDB hypertable) |
| `api_keys` | API key management with soft-delete support |
| `users` | User accounts for fault assignment |
| `faults` | Grouped errors with fingerprint-based deduplication |
| `notices` | Individual error occurrences linked to faults |
| `fault_history` | Audit trail of fault state changes |
| `fault_comments` | Comments on faults |

Migrations are located in `migrations/` and applied with `make migrate`.

## Development

### Make Targets

```bash
make help            # Show all available targets
make build           # Build frontend and backend
make build-frontend  # Build the Vue frontend only
make run             # Run the Go server directly
make test            # Run tests
make clean           # Remove build artifacts
make docker-check    # Check if Docker daemon is running
make docker-up       # Start TimescaleDB container
make docker-down     # Stop TimescaleDB container
make migrate         # Run database migrations
make setup           # docker-up + migrate
make env             # Copy .env.example to .env
```

### Frontend Development

For frontend development with hot reload:

```bash
cd web
npm install
npm run dev
```

This starts the Vite dev server on `http://localhost:5173` with a proxy to the Go backend.

### Troubleshooting

**Docker daemon not running:**
- macOS/Windows: open Docker Desktop
- Linux: `sudo systemctl start docker`
- Verify: `make docker-check`

**Port 5432 already in use:**
- Stop the conflicting PostgreSQL service, or change the port in `docker-compose.yml`

**Database connection errors:**
- Ensure TimescaleDB is running: `docker ps`
- Check container logs: `docker logs log-ingestion-timescaledb`
- Verify health: `docker-compose ps`

**Migration failures:**
- Wait 10-15 seconds after `docker-up` for the database to be ready
- Retry: `make migrate`

## License

MIT

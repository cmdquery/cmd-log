# Log Ingestion Service

A high-performance log ingestion service built in Go that efficiently collects, validates, and stores logs from various service types (Next.js, Ruby on Rails, etc.).

## Features

- **HTTP Ingestion**: REST API endpoint for log ingestion
- **Format Support**: Automatic detection and parsing of JSON and plain text logs
- **Authentication**: API key-based authentication
- **Rate Limiting**: Per-service rate limiting to prevent abuse
- **Validation**: Log validation and sanitization before storage
- **Batching**: Efficient batch processing for high throughput
- **Efficient Storage**: TimescaleDB hypertables optimized for time-series data

## Architecture

The service accepts logs via HTTP POST requests, validates and sanitizes them, batches them for efficiency, and stores them in TimescaleDB.

## Prerequisites

- Go 1.21 or later
- Docker and Docker Compose (for local development)
- TimescaleDB (via Docker or standalone)

## Setup

1. **Clone the repository** (if applicable)

2. **Start TimescaleDB**:
   ```bash
   make docker-up
   ```

3. **Run database migrations**:
   ```bash
   make migrate
   ```

4. **Configure environment variables**:
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

5. **Build and run**:
   ```bash
   make build
   ./bin/server
   ```

   Or run directly:
   ```bash
   make run
   ```

## Configuration

Configuration can be provided via:
- Environment variables (prefixed with `LOG_INGESTION_`)
- YAML config file (`config.yaml`)

### Environment Variables

- `LOG_INGESTION_SERVER_PORT`: Server port (default: 8080)
- `LOG_INGESTION_SERVER_HOST`: Server host (default: 0.0.0.0)
- `LOG_INGESTION_DB_HOST`: Database host (default: localhost)
- `LOG_INGESTION_DB_PORT`: Database port (default: 5432)
- `LOG_INGESTION_DB_USER`: Database user (default: postgres)
- `LOG_INGESTION_DB_PASSWORD`: Database password (default: postgres)
- `LOG_INGESTION_DB_NAME`: Database name (default: logs)
- `LOG_INGESTION_BATCH_SIZE`: Batch size (default: 1000)
- `LOG_INGESTION_BATCH_FLUSH_INTERVAL`: Flush interval (default: 5s)
- `LOG_INGESTION_RATELIMIT_ENABLED`: Enable rate limiting (default: true)
- `LOG_INGESTION_RATELIMIT_DEFAULT_RPS`: Default requests per second (default: 100)
- `LOG_INGESTION_RATELIMIT_BURST`: Burst size (default: 200)
- `LOG_INGESTION_API_KEYS`: Comma-separated list of API keys

## API Endpoints

### Health Check

```bash
GET /health
```

Returns the health status of the service.

### Ingest Single Log

```bash
POST /api/v1/logs
Content-Type: application/json
X-API-Key: your-api-key

{
  "log": {
    "timestamp": "2024-01-01T12:00:00Z",
    "service": "my-service",
    "level": "INFO",
    "message": "Application started",
    "metadata": {
      "user_id": "123",
      "request_id": "abc-123"
    }
  }
}
```

### Ingest Batch Logs

```bash
POST /api/v1/logs/batch
Content-Type: application/json
X-API-Key: your-api-key

{
  "logs": [
    {
      "timestamp": "2024-01-01T12:00:00Z",
      "service": "my-service",
      "level": "INFO",
      "message": "Log entry 1"
    },
    {
      "timestamp": "2024-01-01T12:00:01Z",
      "service": "my-service",
      "level": "ERROR",
      "message": "Log entry 2"
    }
  ]
}
```

## Log Format

### JSON Format

The service accepts structured JSON logs:

```json
{
  "timestamp": "2024-01-01T12:00:00Z",
  "service": "my-service",
  "level": "INFO",
  "message": "Log message",
  "metadata": {
    "key": "value"
  }
}
```

### Plain Text Format

The service also accepts plain text logs in various formats:

```
[2024-01-01T12:00:00Z] INFO my-service: Log message
INFO my-service: Log message
my-service [INFO]: Log message
```

## Authentication

All API endpoints (except `/health`) require authentication via API key. Provide the API key in one of the following ways:

- Header: `X-API-Key: your-api-key`
- Authorization header: `Authorization: Bearer your-api-key`

## Rate Limiting

Rate limiting is enabled by default. Each API key has its own rate limit bucket. Default limits:
- Requests per second: 100
- Burst size: 200

## Development

### Running Tests

```bash
make test
```

### Building

```bash
make build
```

### Docker Commands

```bash
make docker-up    # Start TimescaleDB
make docker-down  # Stop TimescaleDB
```

## Database Schema

The service uses TimescaleDB with a hypertable for efficient time-series storage:

- `id`: Primary key
- `timestamp`: Log timestamp (partitioned by this field)
- `service`: Service name
- `level`: Log level (DEBUG, INFO, WARN, ERROR, etc.)
- `message`: Log message
- `metadata`: JSONB field for additional metadata
- `created_at`: Record creation timestamp

Indexes are created on:
- `timestamp` (descending)
- `service`
- `level`
- `(timestamp, service)` composite index
- `metadata` (GIN index for JSON queries)

## License

MIT


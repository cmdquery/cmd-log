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

Before you begin, ensure you have the following installed:

- **Go 1.21 or later** - [Download Go](https://golang.org/dl/)
- **Docker Desktop** (for macOS/Windows) or Docker Engine (for Linux) - [Download Docker](https://www.docker.com/products/docker-desktop)
- **Docker Compose** - Usually included with Docker Desktop

### Verify Prerequisites

Check that Docker is installed and running:

```bash
# Check Docker version
docker --version

# Verify Docker daemon is running
make docker-check
```

If Docker is not running, start Docker Desktop (macOS/Windows) or the Docker service (Linux).

## Quick Start

1. **Clone the repository** (if applicable):
   ```bash
   git clone <repository-url>
   cd cmd-log
   ```

2. **Verify Docker is running**:
   ```bash
   make docker-check
   ```
   If this fails, start Docker Desktop and try again.

3. **Start TimescaleDB**:
   ```bash
   make docker-up
   ```
   This will start the TimescaleDB container in the background. The first time may take a few minutes to download the image.

4. **Run database migrations**:
   ```bash
   make migrate
   ```
   This creates the necessary database tables and indexes.

5. **Configure environment variables** (optional):
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```
   If you don't create a `.env` file, the service will use default values.

6. **Build and run the service**:
   ```bash
   make build
   ./bin/server
   ```
   
   Or run directly without building:
   ```bash
   make run
   ```

7. **Verify the service is running**:
   ```bash
   curl http://localhost:8080/health
   ```

## Setup (Detailed)

### Step 1: Start Docker

**macOS/Windows:**
- Open Docker Desktop application
- Wait for Docker to start (you'll see a Docker icon in your system tray/menu bar)
- Verify it's running: `make docker-check`

**Linux:**
- Start Docker service: `sudo systemctl start docker`
- Enable Docker to start on boot: `sudo systemctl enable docker`
- Verify it's running: `make docker-check`

### Step 2: Start Database

```bash
make docker-up
```

This command will:
- Check if Docker daemon is running (and show a helpful error if not)
- Pull the TimescaleDB image if needed
- Start the TimescaleDB container on port 5432

**Troubleshooting:**
- If you see "Docker daemon is not running", start Docker Desktop and try again
- If port 5432 is already in use, stop the conflicting service or modify `docker-compose.yml` to use a different port

### Step 3: Run Migrations

```bash
make migrate
```

This creates the database schema with TimescaleDB hypertables optimized for time-series data.

### Step 4: Configure the Service

Create a `.env` file (optional - defaults will be used if not provided):

```bash
cp .env.example .env
```

Edit `.env` with your settings. At minimum, you may want to set:
- `LOG_INGESTION_API_KEYS`: Comma-separated list of API keys for authentication

### Step 5: Run the Service

**Option 1: Build and run**
```bash
make build
./bin/server
```

**Option 2: Run directly (development)**
```bash
make run
```

The service will start on `http://localhost:8080` by default.

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
make docker-check # Check if Docker daemon is running
make docker-up    # Start TimescaleDB container
make docker-down  # Stop TimescaleDB container
```

### Troubleshooting

**Docker daemon not running:**
```bash
# Check Docker status
make docker-check

# If Docker is not running:
# - macOS/Windows: Open Docker Desktop application
# - Linux: sudo systemctl start docker
```

**Port 5432 already in use:**
- Stop the conflicting PostgreSQL service, or
- Modify `docker-compose.yml` to use a different port (e.g., `5433:5432`)

**Database connection errors:**
- Ensure TimescaleDB container is running: `docker ps`
- Check container logs: `docker logs log-ingestion-timescaledb`
- Verify database is healthy: `docker-compose ps`

**Migration failures:**
- Ensure the database container is fully started (wait 10-15 seconds after `docker-up`)
- Check database logs for errors
- Try running migrations again: `make migrate`

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


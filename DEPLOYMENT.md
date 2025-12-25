# Deployment Guide

This document provides comprehensive instructions for deploying the Log Ingestion Service to a server, covering both Docker and systemd deployment methods for staging and production environments.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Database Setup](#database-setup)
- [Configuration](#configuration)
- [Docker Deployment](#docker-deployment)
- [systemd Deployment](#systemd-deployment)
- [Production Considerations](#production-considerations)
- [Health Checks & Monitoring](#health-checks--monitoring)
- [Maintenance](#maintenance)
- [Troubleshooting](#troubleshooting)

## Overview

The Log Ingestion Service is a high-performance HTTP service that collects, validates, and stores logs in TimescaleDB. It supports:

- HTTP REST API for log ingestion
- API key-based authentication
- Rate limiting per API key
- Batch processing for high throughput
- TimescaleDB hypertables for efficient time-series storage

### Deployment Architecture

```
┌─────────────────┐
│  Load Balancer  │ (Optional, for high availability)
└────────┬────────┘
         │
    ┌────▼────┐
    │  App    │ (log-ingestion service)
    │ Service │
    └────┬────┘
         │
    ┌────▼────────┐
    │ TimescaleDB │
    └─────────────┘
```

## Prerequisites

### Server Requirements

**Minimum (Staging/Small Production):**
- CPU: 2 cores
- RAM: 2GB
- Disk: 20GB SSD
- OS: Ubuntu 20.04+ / Debian 11+ / RHEL 8+ / CentOS 8+

**Recommended (Production):**
- CPU: 4+ cores
- RAM: 4GB+
- Disk: 100GB+ SSD
- OS: Ubuntu 22.04 LTS / RHEL 9+

### Software Dependencies

**For Docker Deployment:**
- Docker 20.10+
- Docker Compose 2.0+

**For systemd Deployment:**
- Go 1.21+ (for building)
- TimescaleDB 2.0+ (PostgreSQL 14+)
- PostgreSQL client tools (`psql`)

**Common:**
- curl or wget (for health checks)
- git (for cloning repository)

## Database Setup

### Option 1: Docker-based TimescaleDB (Recommended for Docker Deployment)

TimescaleDB runs in a container managed by Docker Compose. No separate installation needed - see [Docker Deployment](#docker-deployment) section.

### Option 2: Standalone TimescaleDB (Required for systemd Deployment)

#### Ubuntu/Debian Installation

```bash
# Add TimescaleDB PPA
sudo sh -c "echo 'deb https://packagecloud.io/timescale/timescaledb/ubuntu/ $(lsb_release -c -s) main' > /etc/apt/sources.list.d/timescaledb.list"
wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | sudo apt-key add -
sudo apt-get update

# Install PostgreSQL and TimescaleDB
sudo apt-get install -y postgresql-14 postgresql-client-14
sudo apt-get install -y timescaledb-2-postgresql-14

# Tune PostgreSQL for TimescaleDB
sudo timescaledb-tune --quiet --yes

# Start and enable PostgreSQL
sudo systemctl enable postgresql
sudo systemctl start postgresql
```

#### RHEL/CentOS Installation

```bash
# Add TimescaleDB repository
sudo tee /etc/yum.repos.d/timescale_timescaledb.repo <<EOF
[timescale_timescaledb]
name=timescale_timescaledb
baseurl=https://packagecloud.io/timescale/timescaledb/el/\$releasever/\$basearch
repo_gpgcheck=1
gpgcheck=0
enabled=1
gpgkey=https://packagecloud.io/timescale/timescaledb/gpgkey
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300
EOF

# Install PostgreSQL and TimescaleDB
sudo yum install -y postgresql14 postgresql14-server timescaledb-2-postgresql14

# Initialize and start PostgreSQL
sudo /usr/pgsql-14/bin/postgresql-14-setup initdb
sudo systemctl enable postgresql-14
sudo systemctl start postgresql-14

# Tune PostgreSQL for TimescaleDB
sudo timescaledb-tune --quiet --yes
sudo systemctl restart postgresql-14
```

#### Create Database and User

```bash
# Switch to postgres user
sudo -u postgres psql

# In PostgreSQL prompt:
CREATE DATABASE logs;
CREATE USER log_ingestion WITH PASSWORD 'your-secure-password';
GRANT ALL PRIVILEGES ON DATABASE logs TO log_ingestion;

# Enable TimescaleDB extension
\c logs
CREATE EXTENSION IF NOT EXISTS timescaledb;
\q
```

#### Run Migrations

```bash
# Using psql
psql -h localhost -U log_ingestion -d logs -f migrations/001_create_logs_table.sql

# Or if running as postgres user:
sudo -u postgres psql -d logs -f migrations/001_create_logs_table.sql
```

## Configuration

### Environment Variables

The service can be configured via environment variables (prefixed with `LOG_INGESTION_`) or a YAML config file. For production, environment variables are recommended.

#### Server Configuration

```bash
LOG_INGESTION_SERVER_HOST=0.0.0.0          # Server bind address (default: 0.0.0.0)
LOG_INGESTION_SERVER_PORT=8080              # Server port (default: 8080)
```

#### Database Configuration

```bash
LOG_INGESTION_DB_HOST=localhost             # Database host (default: localhost)
LOG_INGESTION_DB_PORT=5432                  # Database port (default: 5432)
LOG_INGESTION_DB_USER=log_ingestion         # Database user (default: postgres)
LOG_INGESTION_DB_PASSWORD=secure-password   # Database password (default: postgres)
LOG_INGESTION_DB_NAME=logs                  # Database name (default: logs)
LOG_INGESTION_DB_SSLMODE=require            # SSL mode: disable, allow, prefer, require (default: disable)
```

#### Batch Processing Configuration

```bash
LOG_INGESTION_BATCH_SIZE=1000               # Batch size (default: 1000)
LOG_INGESTION_BATCH_FLUSH_INTERVAL=5s       # Flush interval (default: 5s)
```

#### Rate Limiting Configuration

```bash
LOG_INGESTION_RATELIMIT_ENABLED=true        # Enable rate limiting (default: true)
LOG_INGESTION_RATELIMIT_DEFAULT_RPS=100     # Requests per second (default: 100)
LOG_INGESTION_RATELIMIT_BURST=200           # Burst size (default: 200)
```

#### Authentication Configuration

```bash
# Comma-separated list of API keys
LOG_INGESTION_API_KEYS=key1,key2,key3
```

### Configuration File (Alternative)

Create `config.yaml` in the application directory:

```yaml
server:
  host: "0.0.0.0"
  port: 8080
  read_timeout: "10s"
  write_timeout: "10s"

database:
  host: "localhost"
  port: 5432
  user: "log_ingestion"
  password: "secure-password"
  dbname: "logs"
  sslmode: "require"

batch:
  size: 1000
  flush_interval: "5s"

ratelimit:
  enabled: true
  default_rps: 100
  burst: 200

auth:
  api_keys:
    - "your-api-key-1"
    - "your-api-key-2"
```

## Docker Deployment

### Prerequisites

- Docker 20.10+ and Docker Compose 2.0+
- Network access to pull images

### Quick Start (Development/Staging)

1. **Clone the repository:**

```bash
git clone <repository-url>
cd cmd-log
```

2. **Create environment file:**

```bash
cat > .env <<EOF
DB_PASSWORD=your-secure-password
DB_USER=postgres
DB_NAME=logs
SERVER_PORT=8080
API_KEYS=your-api-key-1,your-api-key-2
EOF
```

3. **Build and start services:**

```bash
# Build the application image
docker-compose -f docker-compose.prod.yml build

# Start services
docker-compose -f docker-compose.prod.yml up -d

# View logs
docker-compose -f docker-compose.prod.yml logs -f app
```

4. **Run migrations:**

```bash
# Wait for database to be ready
sleep 10

# Run migrations
docker-compose -f docker-compose.prod.yml exec timescaledb psql -U postgres -d logs -f /docker-entrypoint-initdb.d/001_create_logs_table.sql

# Or copy migration file and run manually
docker cp migrations/001_create_logs_table.sql log-ingestion-timescaledb:/tmp/
docker-compose -f docker-compose.prod.yml exec timescaledb psql -U postgres -d logs -f /tmp/001_create_logs_table.sql
```

5. **Verify deployment:**

```bash
curl http://localhost:8080/health
```

### Production Deployment

1. **Prepare production environment file:**

```bash
cat > .env.prod <<EOF
# Database
DB_PASSWORD=$(openssl rand -base64 32)
DB_USER=postgres
DB_NAME=logs
DB_PORT=5432
DB_SSLMODE=prefer

# Server
SERVER_HOST=0.0.0.0
SERVER_PORT=8080

# Application Configuration
BATCH_SIZE=1000
BATCH_FLUSH_INTERVAL=5s
RATELIMIT_ENABLED=true
RATELIMIT_DEFAULT_RPS=100
RATELIMIT_BURST=200

# Security - Generate secure API keys
API_KEYS=$(openssl rand -hex 32),$(openssl rand -hex 32)
EOF

# Secure the file
chmod 600 .env.prod
```

2. **Build production image:**

```bash
docker-compose -f docker-compose.prod.yml build --no-cache
```

3. **Start services:**

```bash
docker-compose -f docker-compose.prod.yml --env-file .env.prod up -d
```

4. **Run migrations** (if not already run):

```bash
docker-compose -f docker-compose.prod.yml exec timescaledb psql -U postgres -d logs -f /docker-entrypoint-initdb.d/001_create_logs_table.sql
```

5. **Manage services:**

```bash
# View status
docker-compose -f docker-compose.prod.yml ps

# View logs
docker-compose -f docker-compose.prod.yml logs -f

# Stop services
docker-compose -f docker-compose.prod.yml down

# Stop and remove volumes (WARNING: deletes data)
docker-compose -f docker-compose.prod.yml down -v

# Restart services
docker-compose -f docker-compose.prod.yml restart

# Update application (after code changes)
docker-compose -f docker-compose.prod.yml build app
docker-compose -f docker-compose.prod.yml up -d app
```

### Docker Deployment Notes

- **Data Persistence:** Database data is stored in Docker volume `timescaledb-data`. Backup this volume for disaster recovery.
- **Networking:** Services communicate via Docker bridge network `log-ingestion-network`.
- **Health Checks:** Both services include health checks. The app waits for the database to be healthy before starting.
- **Resource Limits:** Adjust CPU and memory limits in `docker-compose.prod.yml` based on your workload.

## systemd Deployment

### Prerequisites

- Go 1.21+ installed (for building)
- TimescaleDB installed and configured (see [Database Setup](#database-setup))
- System user for running the service

### Build and Deploy

1. **Create application user:**

```bash
sudo useradd -r -s /bin/false -d /opt/log-ingestion log-ingestion
```

2. **Build the binary:**

```bash
# On build machine (or server with Go installed)
git clone <repository-url>
cd cmd-log
go mod download
CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags="-s -w" -o bin/server ./cmd/server
```

3. **Deploy to server:**

```bash
# Create application directory
sudo mkdir -p /opt/log-ingestion/bin
sudo mkdir -p /opt/log-ingestion/migrations

# Copy binary
sudo cp bin/server /opt/log-ingestion/bin/
sudo chmod +x /opt/log-ingestion/bin/server

# Copy migrations
sudo cp migrations/*.sql /opt/log-ingestion/migrations/

# Set ownership
sudo chown -R log-ingestion:log-ingestion /opt/log-ingestion
```

4. **Create environment file:**

```bash
sudo tee /etc/log-ingestion/env.conf <<EOF
# Server Configuration
LOG_INGESTION_SERVER_HOST=0.0.0.0
LOG_INGESTION_SERVER_PORT=8080

# Database Configuration
LOG_INGESTION_DB_HOST=localhost
LOG_INGESTION_DB_PORT=5432
LOG_INGESTION_DB_USER=log_ingestion
LOG_INGESTION_DB_PASSWORD=your-secure-password
LOG_INGESTION_DB_NAME=logs
LOG_INGESTION_DB_SSLMODE=prefer

# Batch Configuration
LOG_INGESTION_BATCH_SIZE=1000
LOG_INGESTION_BATCH_FLUSH_INTERVAL=5s

# Rate Limiting
LOG_INGESTION_RATELIMIT_ENABLED=true
LOG_INGESTION_RATELIMIT_DEFAULT_RPS=100
LOG_INGESTION_RATELIMIT_BURST=200

# API Keys (comma-separated)
LOG_INGESTION_API_KEYS=your-api-key-1,your-api-key-2
EOF

# Secure the file
sudo chmod 600 /etc/log-ingestion/env.conf
sudo chown log-ingestion:log-ingestion /etc/log-ingestion/env.conf
```

5. **Install systemd service:**

```bash
# Copy service file
sudo cp deploy/log-ingestion.service /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload

# Enable service
sudo systemctl enable log-ingestion

# Start service
sudo systemctl start log-ingestion

# Check status
sudo systemctl status log-ingestion
```

6. **Run database migrations:**

```bash
# If not already run during database setup
sudo -u postgres psql -d logs -f /opt/log-ingestion/migrations/001_create_logs_table.sql
```

### Managing the Service

```bash
# Start service
sudo systemctl start log-ingestion

# Stop service
sudo systemctl stop log-ingestion

# Restart service
sudo systemctl restart log-ingestion

# Reload configuration (graceful restart)
sudo systemctl reload log-ingestion

# View logs
sudo journalctl -u log-ingestion -f

# View recent logs
sudo journalctl -u log-ingestion -n 100

# Check status
sudo systemctl status log-ingestion
```

### Updating the Service

1. **Build new binary** (on build machine)
2. **Copy binary to server:**
```bash
sudo cp bin/server /opt/log-ingestion/bin/
sudo chown log-ingestion:log-ingestion /opt/log-ingestion/bin/server
```
3. **Restart service:**
```bash
sudo systemctl restart log-ingestion
```

## Production Considerations

### Security

#### API Key Management

- **Generate secure API keys:**
```bash
openssl rand -hex 32
```

- **Rotate API keys regularly:** Update `LOG_INGESTION_API_KEYS` and restart the service.

- **Store API keys securely:**
  - Use environment variables or secure configuration files
  - Restrict file permissions: `chmod 600 config-file`
  - Never commit API keys to version control

#### Database Security

- **Use strong passwords:** Generate with `openssl rand -base64 32`
- **Enable SSL/TLS:** Set `LOG_INGESTION_DB_SSLMODE=require`
- **Restrict database access:** Use firewall rules and PostgreSQL `pg_hba.conf`
- **Use dedicated database user:** Grant only necessary privileges

#### Network Security

- **Firewall configuration:**
```bash
# Allow HTTP traffic (adjust port as needed)
sudo ufw allow 8080/tcp

# Allow PostgreSQL only from localhost (for systemd deployment)
sudo ufw allow from 127.0.0.1 to any port 5432
```

- **Reverse Proxy (Recommended):**
  - Use Nginx or Caddy as reverse proxy
  - Enable HTTPS/TLS
  - Add rate limiting at proxy level
  - Hide internal service details

Example Nginx configuration:

```nginx
upstream log_ingestion {
    server 127.0.0.1:8080;
}

server {
    listen 443 ssl http2;
    server_name logs.example.com;

    ssl_certificate /etc/ssl/certs/logs.crt;
    ssl_certificate_key /etc/ssl/private/logs.key;

    location / {
        proxy_pass http://log_ingestion;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Rate limiting
        limit_req zone=api_limit burst=50 nodelay;
    }
}
```

#### Service Hardening (systemd)

The provided systemd service file includes security hardening via systemd security options:
- Non-root user execution
- Restricted file system access
- Limited system calls
- Resource limits

### Performance Tuning

#### Database Tuning

- **Connection pooling:** The application uses pgx connection pooling. Adjust pool size based on workload.
- **TimescaleDB settings:** Use `timescaledb-tune` to optimize PostgreSQL for TimescaleDB.
- **Partitioning:** Logs are automatically partitioned by timestamp via hypertable.

#### Application Tuning

- **Batch size:** Increase `LOG_INGESTION_BATCH_SIZE` for higher throughput (monitor memory usage).
- **Flush interval:** Adjust `LOG_INGESTION_BATCH_FLUSH_INTERVAL` based on latency requirements.
- **Rate limits:** Tune `LOG_INGESTION_RATELIMIT_DEFAULT_RPS` based on expected load.

#### Resource Limits

For Docker deployment, adjust in `docker-compose.prod.yml`:
```yaml
deploy:
  resources:
    limits:
      cpus: '2'
      memory: 2G
```

For systemd, adjust in service file:
```ini
MemoryMax=1G
CPUQuota=200%
```

### High Availability

#### Application Level

- Deploy multiple instances behind a load balancer
- Use sticky sessions if needed (though service is stateless)
- Ensure all instances share the same database

#### Database Level

- **TimescaleDB HA:** Set up PostgreSQL replication (streaming replication)
- **Connection pooling:** Use PgBouncer or similar for connection management
- **Backup strategy:** Regular backups with point-in-time recovery

### Backup and Recovery

#### Database Backups

**Docker Deployment:**

```bash
# Backup database
docker-compose -f docker-compose.prod.yml exec timescaledb pg_dump -U postgres logs | gzip > backup-$(date +%Y%m%d-%H%M%S).sql.gz

# Backup volume
docker run --rm -v log-ingestion-timescaledb-data:/data -v $(pwd):/backup alpine tar czf /backup/timescaledb-backup-$(date +%Y%m%d).tar.gz /data
```

**systemd Deployment:**

```bash
# Backup database
sudo -u postgres pg_dump logs | gzip > backup-$(date +%Y%m%d-%H%M%S).sql.gz

# Automated backup script (add to cron)
#!/bin/bash
BACKUP_DIR=/var/backups/log-ingestion
mkdir -p $BACKUP_DIR
sudo -u postgres pg_dump logs | gzip > $BACKUP_DIR/backup-$(date +%Y%m%d-%H%M%S).sql.gz
# Keep only last 30 days
find $BACKUP_DIR -name "backup-*.sql.gz" -mtime +30 -delete
```

**Restore from backup:**

```bash
# Extract and restore
gunzip < backup-YYYYMMDD-HHMMSS.sql.gz | psql -U postgres -d logs
```

#### Configuration Backups

- Backup environment files and configuration
- Version control deployment scripts
- Document API keys in secure password manager

## Health Checks & Monitoring

### Health Check Endpoint

The service provides a health check endpoint:

```bash
curl http://localhost:8080/health
```

Expected response: `200 OK` with JSON body indicating service status.

### Monitoring Recommendations

#### Application Metrics

Monitor:
- Request rate (requests per second)
- Response times (p50, p95, p99)
- Error rates (4xx, 5xx responses)
- Batch processing metrics (batch size, flush frequency)
- Rate limit hits

#### Database Metrics

Monitor:
- Connection pool usage
- Query performance
- Disk usage
- Table size growth
- Chunk creation (TimescaleDB)

#### System Metrics

Monitor:
- CPU usage
- Memory usage
- Disk I/O
- Network I/O

### Logging

**Docker Deployment:**
- Logs via `docker-compose logs`
- Configured with log rotation (max 10MB, 3 files)

**systemd Deployment:**
- Logs via `journalctl -u log-ingestion`
- Configure persistent logging if needed:
```bash
sudo mkdir -p /var/log/journal
sudo systemd-tmpfiles --create --prefix /var/log/journal
```

### Alerting

Set up alerts for:
- Service down (health check failures)
- High error rates (> 1%)
- High response times (> 1s p95)
- Database connection failures
- Disk space < 20%
- Memory usage > 80%

## Maintenance

### Updating the Service

#### Docker Deployment

```bash
# Pull latest code
git pull

# Rebuild image
docker-compose -f docker-compose.prod.yml build app

# Rolling update (zero downtime with multiple instances)
docker-compose -f docker-compose.prod.yml up -d --no-deps app

# Or restart (brief downtime)
docker-compose -f docker-compose.prod.yml restart app
```

#### systemd Deployment

```bash
# Build new binary
go build -o bin/server ./cmd/server

# Copy to server
sudo cp bin/server /opt/log-ingestion/bin/

# Graceful restart
sudo systemctl restart log-ingestion
```

### Database Migrations

1. **Create migration file:**
```sql
-- migrations/002_add_index.sql
CREATE INDEX IF NOT EXISTS idx_logs_created_at ON logs(created_at);
```

2. **Run migration:**

**Docker:**
```bash
docker cp migrations/002_add_index.sql log-ingestion-timescaledb:/tmp/
docker-compose -f docker-compose.prod.yml exec timescaledb psql -U postgres -d logs -f /tmp/002_add_index.sql
```

**systemd:**
```bash
sudo -u postgres psql -d logs -f migrations/002_add_index.sql
```

### Scaling

#### Horizontal Scaling (Application)

1. Deploy multiple application instances
2. Use load balancer to distribute traffic
3. Ensure all instances use the same database
4. Consider shared rate limiting if needed

#### Vertical Scaling (Database)

- Increase database server resources
- Optimize queries and indexes
- Consider read replicas for query offloading
- Use connection pooling (PgBouncer)

### Maintenance Windows

- Schedule maintenance during low-traffic periods
- Use blue-green deployment for zero-downtime updates
- Test updates in staging environment first
- Keep database backups before major changes

## Troubleshooting

### Service Won't Start

**Check logs:**
```bash
# Docker
docker-compose -f docker-compose.prod.yml logs app

# systemd
sudo journalctl -u log-ingestion -n 50
```

**Common issues:**
- Database connection failure: Check database credentials and network connectivity
- Port already in use: Change `SERVER_PORT` or stop conflicting service
- Permission errors: Check file permissions and user ownership

### Database Connection Issues

**Test connection:**
```bash
# Docker
docker-compose -f docker-compose.prod.yml exec timescaledb psql -U postgres -d logs

# systemd
psql -h localhost -U log_ingestion -d logs
```

**Common issues:**
- Wrong credentials: Verify environment variables
- Database not running: Check `systemctl status postgresql`
- Network issues: Verify `DB_HOST` configuration
- SSL/TLS errors: Adjust `DB_SSLMODE` setting

### High Memory Usage

- Reduce `BATCH_SIZE` if batches are too large
- Check for memory leaks (monitor over time)
- Increase container/system memory limits
- Review rate limiting settings

### High CPU Usage

- Check batch processing frequency
- Review rate limiting settings
- Monitor database query performance
- Consider horizontal scaling

### Rate Limiting Issues

- Verify `LOG_INGESTION_RATELIMIT_ENABLED=true`
- Adjust `LOG_INGESTION_RATELIMIT_DEFAULT_RPS` if needed
- Check if multiple API keys are being used
- Monitor rate limit hit metrics

### Getting Help

1. Check service logs for error messages
2. Verify configuration matches this guide
3. Check database connectivity and health
4. Review system resource usage (CPU, memory, disk)
5. Test health endpoint: `curl http://localhost:8080/health`


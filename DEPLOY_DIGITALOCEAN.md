# DigitalOcean Deployment Guide

Quick start guide for deploying the Log Ingestion Service to a DigitalOcean droplet.

## Prerequisites

Before deploying, ensure you have:

- [ ] A DigitalOcean droplet running Ubuntu 22.04 LTS (or 20.04+)
- [ ] SSH access to the droplet (SSH key added to DigitalOcean)
- [ ] Local machine with:
  - SSH client installed
  - `rsync` or `tar` (for file transfer)
  - `openssl` (for generating secure credentials)
  - `make` (optional, for using Makefile targets)

## Quick Deployment

### Option 1: Using Make (Recommended)

The easiest way to deploy:

```bash
make deploy
```

This will:
1. Prompt you for the droplet IP address
2. Test SSH connection
3. Install Docker if needed
4. Transfer project files
5. Generate secure credentials
6. Build and start services
7. Run migrations
8. Configure firewall

### Option 2: Using Environment Variables

For automated deployments or CI/CD:

```bash
export DROPLET_IP=your.droplet.ip.address
export DROPLET_USER=root  # or your SSH user

make deploy-quick
```

### Option 3: Direct Script Execution

```bash
./deploy/deploy.sh --ip your.droplet.ip.address --user root
```

## Post-Deployment

### Verify Deployment

1. **Check service status:**
   ```bash
   DROPLET_IP=your.droplet.ip.address make deploy-status
   ```

2. **Test health endpoint:**
   ```bash
   curl http://your.droplet.ip.address:8080/health
   ```

3. **View logs:**
   ```bash
   DROPLET_IP=your.droplet.ip.address make deploy-logs
   ```

### Access the Application

- **API Endpoint:** `http://your.droplet.ip.address:8080`
- **Health Check:** `http://your.droplet.ip.address:8080/health`
- **Admin Dashboard:** `http://your.droplet.ip.address:8080/admin` (if configured)

### Save Your API Keys

During deployment, the script will generate and display API keys. **Save these immediately** - they won't be shown again!

To view API keys later, SSH into the droplet and check the `.env` file:
```bash
ssh root@your.droplet.ip.address "cat /opt/cmd-log/.env | grep API_KEYS"
```

## Manual Deployment Steps

If you prefer to deploy manually or need to troubleshoot:

### 1. Prepare the Droplet

SSH into your droplet and run the setup script:

```bash
ssh root@your.droplet.ip.address
curl -fsSL https://raw.githubusercontent.com/your-repo/cmd-log/main/deploy/setup-server.sh | bash
```

Or copy and run the setup script:
```bash
scp deploy/setup-server.sh root@your.droplet.ip.address:/tmp/
ssh root@your.droplet.ip.address "chmod +x /tmp/setup-server.sh && /tmp/setup-server.sh"
```

### 2. Transfer Project Files

```bash
# Using rsync (recommended)
rsync -avz --exclude='.git' --exclude='node_modules' --exclude='bin' \
  --exclude='.env' ./ root@your.droplet.ip.address:/opt/cmd-log/

# Or using tar
tar --exclude='.git' --exclude='node_modules' --exclude='bin' \
  --exclude='.env' -czf - . | ssh root@your.droplet.ip.address \
  "cd /opt/cmd-log && tar -xzf -"
```

### 3. Create Environment File

```bash
ssh root@your.droplet.ip.address "cat > /opt/cmd-log/.env <<EOF
DB_PASSWORD=\$(openssl rand -base64 32)
DB_USER=postgres
DB_NAME=logs
DB_PORT=5432
DB_SSLMODE=prefer
SERVER_HOST=0.0.0.0
SERVER_PORT=8080
BATCH_SIZE=1000
BATCH_FLUSH_INTERVAL=5s
RATELIMIT_ENABLED=true
RATELIMIT_DEFAULT_RPS=100
RATELIMIT_BURST=200
API_KEYS=\$(openssl rand -hex 32),\$(openssl rand -hex 32)
EOF
chmod 600 /opt/cmd-log/.env"
```

### 4. Build and Start Services

```bash
ssh root@your.droplet.ip.address "cd /opt/cmd-log && \
  docker compose -f docker-compose.prod.yml build && \
  docker compose -f docker-compose.prod.yml up -d"
```

### 5. Run Migrations

```bash
ssh root@your.droplet.ip.address "cd /opt/cmd-log && \
  docker compose -f docker-compose.prod.yml exec -T timescaledb \
  psql -U postgres -d logs -f /docker-entrypoint-initdb.d/001_create_logs_table.sql && \
  docker compose -f docker-compose.prod.yml exec -T timescaledb \
  psql -U postgres -d logs -f /docker-entrypoint-initdb.d/002_create_api_keys_table.sql"
```

### 6. Configure Firewall

```bash
ssh root@your.droplet.ip.address "ufw allow 22/tcp && \
  ufw allow 8080/tcp && \
  ufw --force enable"
```

## Managing the Deployment

### View Logs

```bash
# All services
DROPLET_IP=your.droplet.ip.address make deploy-logs

# Specific service
ssh root@your.droplet.ip.address "cd /opt/cmd-log && \
  docker compose -f docker-compose.prod.yml logs -f app"
```

### Restart Services

```bash
ssh root@your.droplet.ip.address "cd /opt/cmd-log && \
  docker compose -f docker-compose.prod.yml restart"
```

### Stop Services

```bash
ssh root@your.droplet.ip.address "cd /opt/cmd-log && \
  docker compose -f docker-compose.prod.yml down"
```

### Update Deployment

To update the application after code changes:

```bash
# Re-run the deployment script (it's idempotent)
make deploy

# Or manually:
ssh root@your.droplet.ip.address "cd /opt/cmd-log && \
  git pull && \
  docker compose -f docker-compose.prod.yml build app && \
  docker compose -f docker-compose.prod.yml up -d app"
```

## Troubleshooting

### SSH Connection Issues

**Problem:** Cannot connect to droplet

**Solutions:**
1. Verify droplet is running in DigitalOcean dashboard
2. Check SSH key is added to DigitalOcean account
3. Verify firewall allows SSH (port 22)
4. Try connecting manually: `ssh root@your.droplet.ip.address`

### Docker Not Installing

**Problem:** Docker installation fails during setup

**Solutions:**
1. Check internet connectivity on droplet
2. Verify droplet has sufficient resources (2GB+ RAM recommended)
3. Run setup script manually: `./deploy/setup-server.sh`
4. Check logs: `journalctl -xe`

### Services Won't Start

**Problem:** Docker containers fail to start

**Solutions:**
1. Check logs: `docker compose -f docker-compose.prod.yml logs`
2. Verify `.env` file exists and has correct format
3. Check disk space: `df -h`
4. Verify port 8080 is not in use: `netstat -tulpn | grep 8080`
5. Check Docker daemon: `systemctl status docker`

### Database Connection Errors

**Problem:** Application cannot connect to database

**Solutions:**
1. Verify database container is running: `docker compose ps`
2. Check database logs: `docker compose logs timescaledb`
3. Verify `.env` file has correct `DB_PASSWORD`
4. Test database connection:
   ```bash
   docker compose exec timescaledb psql -U postgres -d logs
   ```

### Health Check Fails

**Problem:** `/health` endpoint returns error

**Solutions:**
1. Check application logs: `docker compose logs app`
2. Verify application container is running: `docker compose ps`
3. Check if port is accessible: `curl http://localhost:8080/health`
4. Verify firewall allows port 8080

### Migration Errors

**Problem:** Database migrations fail

**Solutions:**
1. Check if migrations already ran (errors may be expected)
2. Verify database is ready: `docker compose exec timescaledb pg_isready`
3. Run migrations manually:
   ```bash
   docker compose exec timescaledb psql -U postgres -d logs \
     -f /docker-entrypoint-initdb.d/001_create_logs_table.sql
   ```

## Security Best Practices

1. **Change Default Credentials:** Always use the generated secure passwords
2. **Use HTTPS:** Set up a reverse proxy (Nginx/Caddy) with SSL certificates
3. **Firewall:** Only open necessary ports (22 for SSH, 8080 for app, or 80/443 if using reverse proxy)
4. **API Keys:** Rotate API keys regularly
5. **Updates:** Keep the system and Docker images updated
6. **Backups:** Set up automated backups for the database volume

## Production Recommendations

For production deployments, consider:

1. **Reverse Proxy:** Use Nginx or Caddy with HTTPS
2. **Domain Name:** Point a domain to your droplet IP
3. **Monitoring:** Set up monitoring (e.g., DigitalOcean monitoring, Prometheus)
4. **Backups:** Automated daily backups of database
5. **Log Rotation:** Configure log rotation for application logs
6. **Resource Limits:** Adjust CPU/memory limits in `docker-compose.prod.yml` based on load
7. **High Availability:** Consider multiple instances behind a load balancer

## Getting Help

If you encounter issues:

1. Check the logs: `make deploy-logs` or `docker compose logs`
2. Verify service status: `make deploy-status`
3. Review the [main deployment guide](DEPLOYMENT.md) for detailed information
4. Check [troubleshooting section](#troubleshooting) above

## Next Steps

After successful deployment:

1. Test the API endpoints with your API keys
2. Set up monitoring and alerts
3. Configure automated backups
4. Set up a reverse proxy with HTTPS (recommended)
5. Review and adjust resource limits based on your workload




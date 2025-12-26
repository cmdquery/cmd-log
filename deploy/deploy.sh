#!/bin/bash

# DigitalOcean Deployment Script
# Deploys the log ingestion service to a DigitalOcean droplet

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Default values
DROPLET_IP="${DROPLET_IP:-}"
DROPLET_USER="${DROPLET_USER:-root}"
APP_DIR="/opt/cmd-log"
DEPLOY_PORT="${DEPLOY_PORT:-8080}"
DOMAIN="${DOMAIN:-}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --ip)
            DROPLET_IP="$2"
            shift 2
            ;;
        --user)
            DROPLET_USER="$2"
            shift 2
            ;;
        --port)
            DEPLOY_PORT="$2"
            shift 2
            ;;
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [--ip IP_ADDRESS] [--user USERNAME] [--port PORT] [--domain DOMAIN]"
            echo ""
            echo "Options:"
            echo "  --ip IP_ADDRESS    DigitalOcean droplet IP address or hostname"
            echo "  --user USERNAME   SSH user (default: root)"
            echo "  --port PORT        Application port (default: 8080)"
            echo "  --domain DOMAIN    Domain name for nginx reverse proxy with SSL (e.g., cmdlog.tech)"
            echo "  --help             Show this help message"
            echo ""
            echo "Environment variables:"
            echo "  DROPLET_IP         DigitalOcean droplet IP address"
            echo "  DROPLET_USER       SSH user (default: root)"
            echo "  DOMAIN             Domain name for nginx setup"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check if droplet IP is provided
if [ -z "$DROPLET_IP" ]; then
    read -p "Enter DigitalOcean droplet IP address or hostname: " DROPLET_IP
    if [ -z "$DROPLET_IP" ]; then
        print_error "Droplet IP address is required"
        exit 1
    fi
fi

print_info "Deploying to: ${DROPLET_USER}@${DROPLET_IP}"
print_info "Application directory: ${APP_DIR}"

# Check if SSH is available
if ! command -v ssh >/dev/null 2>&1; then
    print_error "SSH is not installed. Please install OpenSSH client."
    exit 1
fi

# Test SSH connection
print_info "Testing SSH connection..."
if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${DROPLET_USER}@${DROPLET_IP}" "echo 'SSH connection successful'" >/dev/null 2>&1; then
    print_error "Cannot connect to ${DROPLET_USER}@${DROPLET_IP}"
    print_info "Please ensure:"
    print_info "  1. The droplet is running"
    print_info "  2. SSH key is added to the droplet"
    print_info "  3. Firewall allows SSH (port 22)"
    exit 1
fi
print_success "SSH connection successful"

# Check if rsync is available (preferred) or use scp
USE_RSYNC=false
if command -v rsync >/dev/null 2>&1; then
    USE_RSYNC=true
fi

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Check if Docker is installed on remote server
print_info "Checking Docker installation on remote server..."
DOCKER_INSTALLED=$(ssh "${DROPLET_USER}@${DROPLET_IP}" "command -v docker >/dev/null 2>&1 && echo 'yes' || echo 'no'")

if [ "$DOCKER_INSTALLED" = "no" ]; then
    print_warning "Docker is not installed on the remote server"
    print_info "Installing Docker and Docker Compose..."
    
    # Copy setup script to server
    ssh "${DROPLET_USER}@${DROPLET_IP}" "mkdir -p /tmp/deploy"
    scp "${SCRIPT_DIR}/setup-server.sh" "${DROPLET_USER}@${DROPLET_IP}:/tmp/deploy/setup-server.sh"
    ssh "${DROPLET_USER}@${DROPLET_IP}" "chmod +x /tmp/deploy/setup-server.sh && /tmp/deploy/setup-server.sh"
    
    print_success "Docker installation completed"
else
    print_success "Docker is already installed"
fi

# Verify Docker Compose
print_info "Verifying Docker Compose..."
DOCKER_COMPOSE_CMD=$(ssh "${DROPLET_USER}@${DROPLET_IP}" "command -v docker-compose >/dev/null 2>&1 && echo 'docker-compose' || (docker compose version >/dev/null 2>&1 && echo 'docker compose' || echo 'none')")
if [ "$DOCKER_COMPOSE_CMD" = "none" ]; then
    print_error "Docker Compose is not available"
    exit 1
fi
print_success "Docker Compose is available"

# Create application directory on remote server
print_info "Creating application directory..."
ssh "${DROPLET_USER}@${DROPLET_IP}" "mkdir -p ${APP_DIR}"

# Transfer project files
print_info "Transferring project files..."
EXCLUDE_PATTERNS=(
    "--exclude=.git"
    "--exclude=node_modules"
    "--exclude=bin"
    "--exclude=.env"
    "--exclude=.env.*"
    "--exclude=*.log"
    "--exclude=.DS_Store"
    "--exclude=web/node_modules"
)

if [ "$USE_RSYNC" = true ]; then
    rsync -avz --delete \
        "${EXCLUDE_PATTERNS[@]}" \
        -e "ssh -o StrictHostKeyChecking=no" \
        "${PROJECT_ROOT}/" \
        "${DROPLET_USER}@${DROPLET_IP}:${APP_DIR}/"
else
    # Use tar + ssh for transfer if rsync is not available
    print_info "Using tar for file transfer (rsync not available)"
    cd "$PROJECT_ROOT"
    tar --exclude='.git' \
        --exclude='node_modules' \
        --exclude='bin' \
        --exclude='.env' \
        --exclude='.env.*' \
        --exclude='*.log' \
        --exclude='.DS_Store' \
        --exclude='web/node_modules' \
        -czf - . | ssh "${DROPLET_USER}@${DROPLET_IP}" "cd ${APP_DIR} && tar -xzf -"
fi
print_success "Files transferred"

# Generate secure environment variables
print_info "Generating secure environment variables..."
DB_PASSWORD=$(openssl rand -base64 32)
API_KEY_1=$(openssl rand -hex 32)
API_KEY_2=$(openssl rand -hex 32)
API_KEYS="${API_KEY_1},${API_KEY_2}"

# Check if .env file already exists on server
ENV_EXISTS=$(ssh "${DROPLET_USER}@${DROPLET_IP}" "test -f ${APP_DIR}/.env && echo 'yes' || echo 'no'")

if [ "$ENV_EXISTS" = "yes" ]; then
    print_warning ".env file already exists on server"
    read -p "Do you want to keep existing .env file? (y/n) [n]: " KEEP_ENV
    if [ "${KEEP_ENV:-n}" != "y" ]; then
        print_info "Generating new .env file..."
        ENV_EXISTS="no"
    else
        print_info "Keeping existing .env file"
    fi
fi

if [ "$ENV_EXISTS" = "no" ]; then
    # Create .env file
    ssh "${DROPLET_USER}@${DROPLET_IP}" "cat > ${APP_DIR}/.env <<EOF
# Database Configuration
DB_PASSWORD=${DB_PASSWORD}
DB_USER=postgres
DB_NAME=logs
DB_PORT=5432
DB_SSLMODE=prefer

# Server Configuration
SERVER_HOST=0.0.0.0
SERVER_PORT=${DEPLOY_PORT}

# Application Configuration
BATCH_SIZE=1000
BATCH_FLUSH_INTERVAL=5s
RATELIMIT_ENABLED=true
RATELIMIT_DEFAULT_RPS=100
RATELIMIT_BURST=200

# API Keys (comma-separated)
API_KEYS=${API_KEYS}
EOF
"
    ssh "${DROPLET_USER}@${DROPLET_IP}" "chmod 600 ${APP_DIR}/.env"
    print_success ".env file created with secure credentials"
    
    # Display API keys (user needs to save these)
    echo ""
    print_warning "IMPORTANT: Save these API keys - they won't be shown again!"
    echo "API Key 1: ${API_KEY_1}"
    echo "API Key 2: ${API_KEY_2}"
    echo ""
    read -p "Press Enter to continue..."
fi

# Build Docker images
print_info "Building Docker images..."
ssh "${DROPLET_USER}@${DROPLET_IP}" "cd ${APP_DIR} && ${DOCKER_COMPOSE_CMD} -f docker-compose.prod.yml build --no-cache"
print_success "Docker images built"

# Stop existing containers if running
print_info "Stopping existing containers (if any)..."
ssh "${DROPLET_USER}@${DROPLET_IP}" "cd ${APP_DIR} && ${DOCKER_COMPOSE_CMD} -f docker-compose.prod.yml down" || true

# Start services
print_info "Starting services..."
ssh "${DROPLET_USER}@${DROPLET_IP}" "cd ${APP_DIR} && ${DOCKER_COMPOSE_CMD} -f docker-compose.prod.yml up -d"
print_success "Services started"

# Wait for database to be ready
print_info "Waiting for database to be ready..."
MAX_WAIT=60
WAIT_COUNT=0
while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    if ssh "${DROPLET_USER}@${DROPLET_IP}" "cd ${APP_DIR} && ${DOCKER_COMPOSE_CMD} -f docker-compose.prod.yml exec -T timescaledb pg_isready -U postgres" >/dev/null 2>&1; then
        print_success "Database is ready"
        break
    fi
    WAIT_COUNT=$((WAIT_COUNT + 2))
    if [ $WAIT_COUNT -lt $MAX_WAIT ]; then
        echo -n "."
        sleep 2
    fi
done

if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
    echo ""
    print_error "Database did not become ready within ${MAX_WAIT} seconds"
    exit 1
fi

# Run migrations
print_info "Running database migrations..."
ssh "${DROPLET_USER}@${DROPLET_IP}" "cd ${APP_DIR} && ${DOCKER_COMPOSE_CMD} -f docker-compose.prod.yml exec -T timescaledb psql -U postgres -d logs -f /docker-entrypoint-initdb.d/001_create_logs_table.sql" || true
ssh "${DROPLET_USER}@${DROPLET_IP}" "cd ${APP_DIR} && ${DOCKER_COMPOSE_CMD} -f docker-compose.prod.yml exec -T timescaledb psql -U postgres -d logs -f /docker-entrypoint-initdb.d/002_create_api_keys_table.sql" || true
print_success "Migrations completed"

# Configure firewall
print_info "Configuring firewall..."
if [ -n "$DOMAIN" ]; then
    # If domain is provided, allow nginx ports (80/443) instead of application port
    ssh "${DROPLET_USER}@${DROPLET_IP}" "
        if command -v ufw >/dev/null 2>&1; then
            ufw --force enable >/dev/null 2>&1 || true
            ufw allow 22/tcp >/dev/null 2>&1 || true
            ufw allow 80/tcp >/dev/null 2>&1 || true
            ufw allow 443/tcp >/dev/null 2>&1 || true
            echo 'Firewall configured for nginx (ports 80, 443)'
        else
            echo 'UFW not installed, skipping firewall configuration'
        fi
    "
else
    # No domain, use standard port configuration
    ssh "${DROPLET_USER}@${DROPLET_IP}" "
        if command -v ufw >/dev/null 2>&1; then
            ufw --force enable >/dev/null 2>&1 || true
            ufw allow 22/tcp >/dev/null 2>&1 || true
            ufw allow ${DEPLOY_PORT}/tcp >/dev/null 2>&1 || true
            echo 'Firewall configured'
        else
            echo 'UFW not installed, skipping firewall configuration'
        fi
    "
fi
print_success "Firewall configured"

# Wait for application to be ready
print_info "Waiting for application to be ready..."
MAX_WAIT=30
WAIT_COUNT=0
while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    if ssh "${DROPLET_USER}@${DROPLET_IP}" "curl -sf http://localhost:${DEPLOY_PORT}/health" >/dev/null 2>&1; then
        print_success "Application is ready"
        break
    fi
    WAIT_COUNT=$((WAIT_COUNT + 1))
    sleep 1
done

if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
    print_warning "Application health check timed out (this may be normal if still starting)"
fi

# Setup nginx reverse proxy if domain is provided
if [ -n "$DOMAIN" ]; then
    echo ""
    print_info "Setting up nginx reverse proxy with SSL for ${DOMAIN}..."
    
    # Prompt for email if not provided via environment variable
    if [ -z "${CERTBOT_EMAIL:-}" ]; then
        read -p "Enter email address for Let's Encrypt SSL certificate: " CERTBOT_EMAIL
        if [ -z "$CERTBOT_EMAIL" ]; then
            print_error "Email address is required for SSL certificate"
            exit 1
        fi
    fi
    
    # Transfer nginx setup script to server
    print_info "Transferring nginx setup script..."
    scp "${SCRIPT_DIR}/setup-nginx.sh" "${DROPLET_USER}@${DROPLET_IP}:/tmp/setup-nginx.sh"
    ssh "${DROPLET_USER}@${DROPLET_IP}" "chmod +x /tmp/setup-nginx.sh"
    
    # Execute nginx setup script on remote server
    print_info "Running nginx setup on remote server..."
    if ssh "${DROPLET_USER}@${DROPLET_IP}" "sudo /tmp/setup-nginx.sh ${DOMAIN} ${CERTBOT_EMAIL}"; then
        print_success "Nginx reverse proxy configured successfully"
    else
        print_warning "Nginx setup failed, but deployment completed"
        print_warning "Application is still accessible on http://${DROPLET_IP}:${DEPLOY_PORT}"
        print_warning "You can manually run: ssh ${DROPLET_USER}@${DROPLET_IP} 'sudo /tmp/setup-nginx.sh ${DOMAIN} <email>'"
    fi
    
    # Clean up temporary script
    ssh "${DROPLET_USER}@${DROPLET_IP}" "rm -f /tmp/setup-nginx.sh" || true
fi

# Display deployment information
echo ""
print_success "Deployment completed successfully!"
echo ""
print_info "Deployment Details:"
echo "  Server: ${DROPLET_USER}@${DROPLET_IP}"
if [ -n "$DOMAIN" ]; then
    echo "  Application URL: https://${DOMAIN}"
    echo "  Health Check: https://${DOMAIN}/health"
    echo "  (Also available at: http://${DROPLET_IP}:${DEPLOY_PORT})"
else
    echo "  Application URL: http://${DROPLET_IP}:${DEPLOY_PORT}"
    echo "  Health Check: http://${DROPLET_IP}:${DEPLOY_PORT}/health"
fi
echo "  Application Directory: ${APP_DIR}"
echo ""
print_info "Useful Commands:"
echo "  View logs: ssh ${DROPLET_USER}@${DROPLET_IP} 'cd ${APP_DIR} && ${DOCKER_COMPOSE_CMD} -f docker-compose.prod.yml logs -f'"
echo "  Stop services: ssh ${DROPLET_USER}@${DROPLET_IP} 'cd ${APP_DIR} && ${DOCKER_COMPOSE_CMD} -f docker-compose.prod.yml down'"
echo "  Restart services: ssh ${DROPLET_USER}@${DROPLET_IP} 'cd ${APP_DIR} && ${DOCKER_COMPOSE_CMD} -f docker-compose.prod.yml restart'"
echo "  View status: ssh ${DROPLET_USER}@${DROPLET_IP} 'cd ${APP_DIR} && ${DOCKER_COMPOSE_CMD} -f docker-compose.prod.yml ps'"
if [ -n "$DOMAIN" ]; then
    echo "  View nginx status: ssh ${DROPLET_USER}@${DROPLET_IP} 'sudo systemctl status nginx'"
    echo "  View nginx logs: ssh ${DROPLET_USER}@${DROPLET_IP} 'sudo tail -f /var/log/nginx/error.log'"
fi
echo ""


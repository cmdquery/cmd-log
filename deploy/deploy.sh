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

# Function to check if database password from .env matches existing database
check_db_password_match() {
    local server_user="$1"
    local server_ip="$2"
    local app_dir="$3"
    local compose_cmd="$4"
    
    # Check if database volume exists
    local volume_exists=$(ssh "${server_user}@${server_ip}" "docker volume ls -q | grep -q 'cmd-log_timescaledb-data' && echo 'yes' || echo 'no'")
    
    if [ "$volume_exists" = "no" ]; then
        # No existing volume, password will be set on first init
        return 0
    fi
    
    # Try to read DB_PASSWORD from .env file on server
    local db_password=$(ssh "${server_user}@${server_ip}" "grep '^DB_PASSWORD=' ${app_dir}/.env 2>/dev/null | cut -d'=' -f2- | tr -d '\"' | tr -d \"'\"")
    
    if [ -z "$db_password" ]; then
        # Can't read password, assume mismatch
        return 1
    fi
    
    # Check if database container is running
    local db_running=$(ssh "${server_user}@${server_ip}" "cd ${app_dir} && ${compose_cmd} -f docker-compose.prod.yml ps timescaledb 2>/dev/null | grep -q 'Up' && echo 'yes' || echo 'no'")
    
    if [ "$db_running" = "yes" ]; then
        # Try to connect with the password from .env
        if ssh "${server_user}@${server_ip}" "cd ${app_dir} && PGPASSWORD='${db_password}' ${compose_cmd} -f docker-compose.prod.yml exec -T timescaledb psql -U postgres -d logs -c 'SELECT 1;' >/dev/null 2>&1"; then
            return 0
        else
            return 1
        fi
    fi
    
    # Database not running, can't check - assume mismatch to be safe
    return 1
}

# Function to reset database volume
reset_db_volume() {
    local server_user="$1"
    local server_ip="$2"
    local app_dir="$3"
    local compose_cmd="$4"
    
    print_warning "Resetting database volume - all data will be lost!"
    
    # Stop containers
    ssh "${server_user}@${server_ip}" "cd ${app_dir} && ${compose_cmd} -f docker-compose.prod.yml down -v" || true
    
    # Remove volume explicitly
    ssh "${server_user}@${server_ip}" "docker volume rm cmd-log_timescaledb-data 2>/dev/null" || true
    
    print_success "Database volume reset"
}

# Function to update database password (only works if we can connect with old password)
update_db_password() {
    local server_user="$1"
    local server_ip="$2"
    local app_dir="$3"
    local compose_cmd="$4"
    local new_password="$5"
    
    print_info "Attempting to update database password..."
    
    # This is tricky - we need the old password to change it
    # For now, we'll just note that this requires manual intervention
    print_warning "Automatic password update requires the old password"
    print_info "To update manually, connect to the database and run:"
    print_info "  ALTER USER postgres WITH PASSWORD '${new_password}';"
    
    return 1
}

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Load configuration file if it exists (before setting defaults)
# This allows config file values to be used as defaults, which can be overridden by flags
CONFIG_FILE="${SCRIPT_DIR}/.deploy-config"
if [ -f "$CONFIG_FILE" ]; then
    # Source the config file to load default values
    # Temporarily disable exit on error in case config file has issues
    set +e
    source "$CONFIG_FILE" 2>/dev/null
    set -e
fi

# Default values (can be overridden by config file, environment variables, or command-line flags)
DROPLET_IP="${DROPLET_IP:-}"
DROPLET_USER="${DROPLET_USER:-root}"
APP_DIR="/opt/cmd-log"
DEPLOY_PORT="${DEPLOY_PORT:-8080}"
DOMAIN="${DOMAIN:-}"
CERTBOT_EMAIL="${CERTBOT_EMAIL:-}"
RESET_DB="${RESET_DB:-false}"

# Managed database configuration (from .deploy-config)
DB_HOST="${DB_HOST:-}"
DB_PORT="${DB_PORT:-25060}"
DB_USER="${DB_USER:-}"
DB_PASSWORD="${DB_PASSWORD:-}"
DB_NAME="${DB_NAME:-logs}"
DB_SSLMODE="${DB_SSLMODE:-require}"

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
        --reset-db)
            RESET_DB="true"
            shift
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
            echo "Configuration:"
            echo "  Default values can be set in deploy/.deploy-config file"
            echo "  Copy deploy/.deploy-config.example to deploy/.deploy-config and edit"
            echo ""
            echo "Environment variables:"
            echo "  DROPLET_IP         DigitalOcean droplet IP address"
            echo "  DROPLET_USER       SSH user (default: root)"
            echo "  DOMAIN             Domain name for nginx setup"
            echo ""
            echo "Precedence (highest to lowest):"
            echo "  1. Command-line flags"
            echo "  2. Environment variables"
            echo "  3. Config file (deploy/.deploy-config)"
            echo "  4. Script defaults"
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

# Validate managed database configuration
print_info "Validating managed database configuration..."
if [ -z "$DB_HOST" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]; then
    print_error "Managed database configuration is incomplete!"
    print_error "Please set DB_HOST, DB_USER, and DB_PASSWORD in deploy/.deploy-config"
    print_info "Example:"
    print_info "  DB_HOST=\"your-db-host.db.ondigitalocean.com\""
    print_info "  DB_PORT=\"25060\""
    print_info "  DB_USER=\"your-db-user\""
    print_info "  DB_PASSWORD=\"your-db-password\""
    print_info "  DB_NAME=\"logs\""
    print_info "  DB_SSLMODE=\"require\""
    exit 1
fi
print_success "Managed database configuration validated"

# Check if rsync is available (preferred) or use scp
USE_RSYNC=false
if command -v rsync >/dev/null 2>&1; then
    USE_RSYNC=true
fi

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
    "--exclude=integrations"
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
        --exclude='integrations' \
        -czf - . | ssh "${DROPLET_USER}@${DROPLET_IP}" "cd ${APP_DIR} && tar -xzf -"
fi
print_success "Files transferred"

# Function to update database configuration in existing .env file
update_db_config_in_env() {
    local server_user="$1"
    local server_ip="$2"
    local app_dir="$3"
    local db_host="$4"
    local db_port="$5"
    local db_user="$6"
    local db_password="$7"
    local db_name="$8"
    local db_sslmode="$9"
    
    print_info "Updating database configuration in existing .env file..."
    
    # Use a temporary file to update .env safely
    ssh "${server_user}@${server_ip}" "cat > /tmp/update_env.sh <<'ENVUPDATE'
#!/bin/bash
ENV_FILE=\"${app_dir}/.env\"
TEMP_FILE=\"\${ENV_FILE}.tmp\"

# Read existing .env and update database variables
while IFS= read -r line || [ -n \"\$line\" ]; do
    if [[ \"\$line\" =~ ^DB_HOST= ]]; then
        echo \"DB_HOST=${db_host}\"
    elif [[ \"\$line\" =~ ^DB_PORT= ]]; then
        echo \"DB_PORT=${db_port}\"
    elif [[ \"\$line\" =~ ^DB_USER= ]]; then
        echo \"DB_USER=${db_user}\"
    elif [[ \"\$line\" =~ ^DB_PASSWORD= ]]; then
        echo \"DB_PASSWORD=${db_password}\"
    elif [[ \"\$line\" =~ ^DB_NAME= ]]; then
        echo \"DB_NAME=${db_name}\"
    elif [[ \"\$line\" =~ ^DB_SSLMODE= ]]; then
        echo \"DB_SSLMODE=${db_sslmode}\"
    else
        echo \"\$line\"
    fi
done < \"\${ENV_FILE}\" > \"\${TEMP_FILE}\"

# Check if DB variables exist, if not add them
if ! grep -q \"^DB_HOST=\" \"\${TEMP_FILE}\"; then
    echo \"DB_HOST=${db_host}\" >> \"\${TEMP_FILE}\"
fi
if ! grep -q \"^DB_PORT=\" \"\${TEMP_FILE}\"; then
    echo \"DB_PORT=${db_port}\" >> \"\${TEMP_FILE}\"
fi
if ! grep -q \"^DB_USER=\" \"\${TEMP_FILE}\"; then
    echo \"DB_USER=${db_user}\" >> \"\${TEMP_FILE}\"
fi
if ! grep -q \"^DB_PASSWORD=\" \"\${TEMP_FILE}\"; then
    echo \"DB_PASSWORD=${db_password}\" >> \"\${TEMP_FILE}\"
fi
if ! grep -q \"^DB_NAME=\" \"\${TEMP_FILE}\"; then
    echo \"DB_NAME=${db_name}\" >> \"\${TEMP_FILE}\"
fi
if ! grep -q \"^DB_SSLMODE=\" \"\${TEMP_FILE}\"; then
    echo \"DB_SSLMODE=${db_sslmode}\" >> \"\${TEMP_FILE}\"
fi

mv \"\${TEMP_FILE}\" \"\${ENV_FILE}\"
chmod 600 \"\${ENV_FILE}\"
ENVUPDATE
chmod +x /tmp/update_env.sh && /tmp/update_env.sh && rm -f /tmp/update_env.sh"
    
    print_success "Database configuration updated in .env file"
}

# Generate secure environment variables (API keys only - DB config comes from .deploy-config)
print_info "Generating secure environment variables..."
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
        # Update database configuration even when keeping existing file
        update_db_config_in_env "${DROPLET_USER}" "${DROPLET_IP}" "${APP_DIR}" \
            "${DB_HOST}" "${DB_PORT}" "${DB_USER}" "${DB_PASSWORD}" "${DB_NAME}" "${DB_SSLMODE}"
    fi
fi

if [ "$ENV_EXISTS" = "no" ]; then
    # Create .env file with managed database configuration
    ssh "${DROPLET_USER}@${DROPLET_IP}" "cat > ${APP_DIR}/.env <<EOF
# Database Configuration (Managed DigitalOcean Database)
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_NAME=${DB_NAME}
DB_SSLMODE=${DB_SSLMODE}

# Server Configuration
SERVER_HOST=0.0.0.0
SERVER_PORT=${DEPLOY_PORT}

# Application Configuration
BATCH_SIZE=1000
BATCH_FLUSH_INTERVAL=5s
RATELIMIT_ENABLED=true
RATELIMIT_DEFAULT_RPS=100
RATELIMIT_BURST=200

# API Keys (comma-separated) - for regular log ingestion endpoints (stored in database)
API_KEYS=${API_KEYS}

# Admin API Keys (comma-separated) - for admin endpoints
ADMIN_API_KEYS=${API_KEYS}
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

# Test managed database connection
print_info "Testing managed database connection..."
if ssh "${DROPLET_USER}@${DROPLET_IP}" "PGPASSWORD='${DB_PASSWORD}' psql -h ${DB_HOST} -p ${DB_PORT} -U ${DB_USER} -d ${DB_NAME} -c 'SELECT 1;' >/dev/null 2>&1"; then
    print_success "Managed database connection successful"
else
    print_warning "Could not verify managed database connection (psql may not be installed on server)"
    print_info "Database connection will be tested when application starts"
fi

# Run migrations against managed database
print_info "Running database migrations against managed database..."
# Check if psql is available on the server, if not, we'll need to run migrations from within a container
if ssh "${DROPLET_USER}@${DROPLET_IP}" "command -v psql >/dev/null 2>&1"; then
    # Use psql directly on server
    ssh "${DROPLET_USER}@${DROPLET_IP}" "PGPASSWORD='${DB_PASSWORD}' psql -h ${DB_HOST} -p ${DB_PORT} -U ${DB_USER} -d ${DB_NAME} -f ${APP_DIR}/migrations/001_create_logs_table.sql" || true
    ssh "${DROPLET_USER}@${DROPLET_IP}" "PGPASSWORD='${DB_PASSWORD}' psql -h ${DB_HOST} -p ${DB_PORT} -U ${DB_USER} -d ${DB_NAME} -f ${APP_DIR}/migrations/002_create_api_keys_table.sql" || true
else
    # Use a temporary postgres container to run migrations
    print_info "psql not found on server, using temporary postgres container for migrations..."
    ssh "${DROPLET_USER}@${DROPLET_IP}" "docker run --rm -v ${APP_DIR}/migrations:/migrations -e PGPASSWORD='${DB_PASSWORD}' postgres:16-alpine psql -h ${DB_HOST} -p ${DB_PORT} -U ${DB_USER} -d ${DB_NAME} -f /migrations/001_create_logs_table.sql" || true
    ssh "${DROPLET_USER}@${DROPLET_IP}" "docker run --rm -v ${APP_DIR}/migrations:/migrations -e PGPASSWORD='${DB_PASSWORD}' postgres:16-alpine psql -h ${DB_HOST} -p ${DB_PORT} -U ${DB_USER} -d ${DB_NAME} -f /migrations/002_create_api_keys_table.sql" || true
fi
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


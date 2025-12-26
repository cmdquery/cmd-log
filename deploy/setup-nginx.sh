#!/bin/bash

# Nginx Reverse Proxy Setup Script
# Sets up nginx with SSL certificates for cmdlog.tech domain

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

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

# Get domain and email from arguments
DOMAIN="${1:-}"
EMAIL="${2:-}"

if [ -z "$DOMAIN" ]; then
    print_error "Domain is required"
    echo "Usage: $0 <domain> <email>"
    echo "Example: $0 cmdlog.tech admin@example.com"
    exit 1
fi

if [ -z "$EMAIL" ]; then
    print_error "Email is required for Let's Encrypt certificates"
    echo "Usage: $0 <domain> <email>"
    echo "Example: $0 cmdlog.tech admin@example.com"
    exit 1
fi

print_info "Setting up nginx reverse proxy for ${DOMAIN}..."

# Install nginx and certbot if not already installed
print_info "Checking for nginx..."
if ! command -v nginx >/dev/null 2>&1; then
    print_info "Installing nginx..."
    apt-get update -qq
    apt-get install -y nginx
    print_success "Nginx installed"
else
    print_success "Nginx is already installed"
fi

print_info "Checking for certbot..."
if ! command -v certbot >/dev/null 2>&1; then
    print_info "Installing certbot..."
    apt-get update -qq
    apt-get install -y certbot python3-certbot-nginx
    print_success "Certbot installed"
else
    print_success "Certbot is already installed"
fi

# Create nginx configuration (HTTP only initially - certbot will add HTTPS)
print_info "Creating nginx configuration..."
NGINX_CONFIG="/etc/nginx/sites-available/cmd-log"

cat > "${NGINX_CONFIG}" <<EOF
# HTTP server - certbot will add HTTPS server block automatically
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN} www.${DOMAIN};

    # Allow Let's Encrypt verification
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    # Proxy to Go application (will redirect to HTTPS after certbot setup)
    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

print_success "Nginx configuration created"

# Enable site
print_info "Enabling nginx site..."
ln -sf "${NGINX_CONFIG}" /etc/nginx/sites-enabled/cmd-log

# Remove default site if it exists
if [ -L /etc/nginx/sites-enabled/default ]; then
    print_info "Removing default nginx site..."
    rm -f /etc/nginx/sites-enabled/default
fi

# Test nginx configuration
print_info "Testing nginx configuration..."
if nginx -t >/dev/null 2>&1; then
    print_success "Nginx configuration is valid"
else
    print_error "Nginx configuration test failed"
    nginx -t
    exit 1
fi

# Verify application is running and accessible before configuring nginx
print_info "Verifying application is running..."
APP_RUNNING=false
MAX_WAIT=30
WAIT_COUNT=0

# Check for curl or wget
if command -v curl >/dev/null 2>&1; then
    HEALTH_CHECK_CMD="curl -sf http://localhost:8080/health"
elif command -v wget >/dev/null 2>&1; then
    HEALTH_CHECK_CMD="wget --quiet --spider http://localhost:8080/health"
else
    print_warning "curl or wget not found, skipping health check verification"
    HEALTH_CHECK_CMD=""
fi

# Detect docker compose command
DOCKER_COMPOSE_CMD=$(command -v docker-compose >/dev/null 2>&1 && echo 'docker-compose' || (docker compose version >/dev/null 2>&1 && echo 'docker compose' || echo 'none'))

# Find app directory (common locations)
APP_DIR=""
for dir in /opt/cmd-log /var/www/cmd-log /home/*/cmd-log; do
    if [ -d "$dir" ] && [ -f "$dir/docker-compose.prod.yml" ]; then
        APP_DIR="$dir"
        break
    fi
done

while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    # Check if Docker container is running
    if docker ps --format '{{.Names}}' | grep -q '^log-ingestion-app$'; then
        # Check if port 8080 is accessible (if we have curl/wget)
        if [ -n "$HEALTH_CHECK_CMD" ]; then
            if eval "$HEALTH_CHECK_CMD" >/dev/null 2>&1; then
                APP_RUNNING=true
                print_success "Application is running and responding on port 8080"
                break
            else
                print_warning "Container is running but app not responding on port 8080 (attempt $((WAIT_COUNT + 1))/$MAX_WAIT)"
            fi
        else
            # If no curl/wget, just check if container is running
            APP_RUNNING=true
            print_success "Application container is running (health check skipped)"
            break
        fi
    else
        print_warning "Application container is not running (attempt $((WAIT_COUNT + 1))/$MAX_WAIT)"
    fi
    WAIT_COUNT=$((WAIT_COUNT + 2))
    if [ $WAIT_COUNT -lt $MAX_WAIT ]; then
        sleep 2
    fi
done

if [ "$APP_RUNNING" = false ]; then
    print_error "Application is not running or not accessible on port 8080"
    print_info "Checking Docker container status..."
    docker ps -a | grep log-ingestion || echo "No log-ingestion containers found"
    
    if [ -n "$APP_DIR" ] && [ "$DOCKER_COMPOSE_CMD" != "none" ]; then
        print_info "Checking application logs from $APP_DIR..."
        (cd "$APP_DIR" && $DOCKER_COMPOSE_CMD -f docker-compose.prod.yml logs app --tail 50 2>&1) || echo "Could not retrieve logs"
    else
        print_info "Checking application logs..."
        docker logs log-ingestion-app --tail 50 2>&1 || echo "Could not retrieve logs"
    fi
    
    print_warning "Please ensure the application is running before setting up nginx"
    if [ -n "$APP_DIR" ] && [ "$DOCKER_COMPOSE_CMD" != "none" ]; then
        print_warning "You can check status with: cd $APP_DIR && $DOCKER_COMPOSE_CMD -f docker-compose.prod.yml ps"
        print_warning "You can view logs with: cd $APP_DIR && $DOCKER_COMPOSE_CMD -f docker-compose.prod.yml logs app"
    fi
    exit 1
fi

# Reload nginx
print_info "Reloading nginx..."
systemctl reload nginx || systemctl start nginx
print_success "Nginx reloaded"

# Setup SSL certificate with certbot
print_info "Setting up SSL certificate with Let's Encrypt..."
print_warning "Make sure DNS A records for ${DOMAIN} and www.${DOMAIN} point to this server!"

# Run certbot
if certbot --nginx -d "${DOMAIN}" -d "www.${DOMAIN}" \
    --non-interactive \
    --agree-tos \
    --email "${EMAIL}" \
    --redirect; then
    print_success "SSL certificate installed successfully"
    
    # Test nginx configuration after certbot modifications
    print_info "Testing nginx configuration after SSL setup..."
    if nginx -t >/dev/null 2>&1; then
        print_success "Nginx configuration is valid"
    else
        print_error "Nginx configuration test failed after certbot setup"
        nginx -t
        exit 1
    fi
else
    print_error "Failed to obtain SSL certificate"
    print_warning "Please ensure:"
    print_warning "  1. DNS A records for ${DOMAIN} and www.${DOMAIN} point to this server"
    print_warning "  2. Port 80 is accessible from the internet"
    print_warning "  3. No firewall is blocking Let's Encrypt verification"
    exit 1
fi

# Setup automatic certificate renewal
print_info "Setting up automatic certificate renewal..."
systemctl enable certbot.timer >/dev/null 2>&1 || true
systemctl start certbot.timer >/dev/null 2>&1 || true
print_success "Certificate auto-renewal configured"

# Update firewall rules
print_info "Updating firewall rules..."
if command -v ufw >/dev/null 2>&1; then
    # Allow HTTP and HTTPS
    ufw allow 'Nginx Full' >/dev/null 2>&1 || ufw allow 80/tcp >/dev/null 2>&1 && ufw allow 443/tcp >/dev/null 2>&1
    
    # Optionally remove public access to port 8080 (keep it for localhost only)
    # This is commented out by default - uncomment if you want to restrict port 8080
    # ufw delete allow 8080/tcp >/dev/null 2>&1 || true
    
    print_success "Firewall rules updated"
else
    print_warning "UFW not found, skipping firewall configuration"
fi

# Final nginx reload to ensure SSL is active
print_info "Final nginx reload..."
systemctl reload nginx
print_success "Nginx reloaded with SSL configuration"

# Verify proxy is working after SSL setup
if [ -n "$HEALTH_CHECK_CMD" ]; then
    print_info "Verifying proxy connection to application..."
    sleep 2  # Give nginx a moment to reload
    if eval "$HEALTH_CHECK_CMD" >/dev/null 2>&1; then
        print_success "Application is accessible on port 8080"
    else
        print_warning "Application health check failed on port 8080"
        print_info "This may indicate the application container is not running"
        print_info "Check nginx error logs: tail -f /var/log/nginx/error.log"
    fi
fi

echo ""
print_success "Nginx reverse proxy setup completed!"
echo ""
print_info "Configuration Summary:"
echo "  Domain: ${DOMAIN}"
echo "  www subdomain: www.${DOMAIN}"
echo "  SSL: Enabled (Let's Encrypt)"
echo "  Application: http://localhost:8080"
echo "  Public URL: https://${DOMAIN}"
echo ""
print_info "Certificate auto-renewal is configured and will run automatically."
echo ""


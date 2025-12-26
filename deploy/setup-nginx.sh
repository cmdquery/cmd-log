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

# Create nginx configuration
print_info "Creating nginx configuration..."
NGINX_CONFIG="/etc/nginx/sites-available/cmd-log"

cat > "${NGINX_CONFIG}" <<EOF
# HTTP server - redirect to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN} www.${DOMAIN};

    # Allow Let's Encrypt verification
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    # Redirect all other traffic to HTTPS
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

# HTTPS server - will be updated by certbot
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${DOMAIN} www.${DOMAIN};

    # SSL configuration (will be updated by certbot)
    # ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    
    # SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Increase body size for log ingestion
    client_max_body_size 10M;

    # Proxy to Go application
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
    --redirect \
    --quiet; then
    print_success "SSL certificate installed successfully"
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


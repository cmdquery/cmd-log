#!/bin/bash

# Server Setup Script for DigitalOcean Droplet
# Installs Docker, Docker Compose, and configures the server

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    print_error "This script must be run as root"
    exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
else
    print_error "Cannot detect OS"
    exit 1
fi

print_info "Detected OS: ${OS} ${VER}"

# Update package manager
print_info "Updating package manager..."
if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    apt-get update -qq
    apt-get install -y -qq curl wget git ca-certificates gnupg lsb-release
elif [ "$OS" = "rhel" ] || [ "$OS" = "centos" ] || [ "$OS" = "fedora" ]; then
    if command -v dnf >/dev/null 2>&1; then
        dnf install -y -q curl wget git ca-certificates
    else
        yum install -y -q curl wget git ca-certificates
    fi
else
    print_error "Unsupported OS: ${OS}"
    exit 1
fi
print_success "Package manager updated"

# Install Docker
if command -v docker >/dev/null 2>&1; then
    DOCKER_VERSION=$(docker --version)
    print_success "Docker is already installed: ${DOCKER_VERSION}"
else
    print_info "Installing Docker..."
    
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        # Remove old versions
        apt-get remove -y -qq docker docker-engine docker.io containerd runc 2>/dev/null || true
        
        # Install Docker using official script
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        sh /tmp/get-docker.sh
        rm /tmp/get-docker.sh
        
    elif [ "$OS" = "rhel" ] || [ "$OS" = "centos" ] || [ "$OS" = "fedora" ]; then
        # Remove old versions
        yum remove -y -q docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null || true
        
        # Install Docker using official script
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        sh /tmp/get-docker.sh
        rm /tmp/get-docker.sh
    fi
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    print_success "Docker installed"
fi

# Install Docker Compose
if docker compose version >/dev/null 2>&1; then
    COMPOSE_VERSION=$(docker compose version)
    print_success "Docker Compose is already installed: ${COMPOSE_VERSION}"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_VERSION=$(docker-compose --version)
    print_success "Docker Compose is already installed: ${COMPOSE_VERSION}"
else
    print_info "Installing Docker Compose..."
    
    # Install Docker Compose plugin (preferred method)
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        apt-get install -y -qq docker-compose-plugin
    elif [ "$OS" = "rhel" ] || [ "$OS" = "centos" ] || [ "$OS" = "fedora" ]; then
        if command -v dnf >/dev/null 2>&1; then
            dnf install -y -q docker-compose-plugin
        else
            yum install -y -q docker-compose-plugin
        fi
    fi
    
    # Fallback: install standalone docker-compose if plugin not available
    if ! docker compose version >/dev/null 2>&1; then
        DOCKER_COMPOSE_VERSION="v2.24.0"
        curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
    
    print_success "Docker Compose installed"
fi

# Configure firewall (UFW)
if command -v ufw >/dev/null 2>&1; then
    print_info "Configuring firewall..."
    ufw --force enable >/dev/null 2>&1 || true
    ufw allow 22/tcp >/dev/null 2>&1 || true
    print_success "Firewall configured (SSH allowed)"
else
    print_warning "UFW not installed. Consider installing it for better security:"
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        print_info "  apt-get install -y ufw"
    elif [ "$OS" = "rhel" ] || [ "$OS" = "centos" ] || [ "$OS" = "fedora" ]; then
        print_info "  yum install -y firewalld  # or dnf install -y firewalld"
    fi
fi

# Create application directory
print_info "Creating application directory..."
mkdir -p /opt/cmd-log
print_success "Application directory created: /opt/cmd-log"

# Summary
echo ""
print_success "Server setup completed!"
echo ""
print_info "Installed components:"
echo "  - Docker: $(docker --version)"
if docker compose version >/dev/null 2>&1; then
    echo "  - Docker Compose: $(docker compose version)"
elif command -v docker-compose >/dev/null 2>&1; then
    echo "  - Docker Compose: $(docker-compose --version)"
fi
echo ""
print_info "Next steps:"
echo "  1. Run the deployment script from your local machine"
echo "  2. Or manually clone the repository and configure the application"
echo ""




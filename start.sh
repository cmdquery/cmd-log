#!/bin/bash

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

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Step 1: Check Prerequisites
echo -e "\n${BLUE}=== Checking Prerequisites ===${NC}\n"

# Check Docker
if ! command_exists docker; then
    print_error "Docker is not installed. Please install Docker Desktop and try again."
    exit 1
fi

# Check if Docker daemon is running
if ! docker info >/dev/null 2>&1; then
    print_error "Docker daemon is not running. Please start Docker Desktop and try again."
    exit 1
fi
print_success "Docker is installed and running"

# Check Go (optional, but warn if missing)
if ! command_exists go; then
    print_warning "Go is not installed. The server may not start correctly."
else
    GO_VERSION=$(go version | awk '{print $3}')
    print_success "Go is installed ($GO_VERSION)"
fi

# Check Docker Compose
if ! command_exists docker-compose && ! docker compose version >/dev/null 2>&1; then
    print_error "Docker Compose is not available. Please install Docker Compose and try again."
    exit 1
fi

# Determine docker-compose command (docker-compose or docker compose)
if command_exists docker-compose; then
    DOCKER_COMPOSE="docker-compose"
else
    DOCKER_COMPOSE="docker compose"
fi
print_success "Docker Compose is available"

# Step 2: Start Database
echo -e "\n${BLUE}=== Starting Database ===${NC}\n"

print_info "Starting TimescaleDB container..."
if $DOCKER_COMPOSE up -d >/dev/null 2>&1; then
    print_success "TimescaleDB container started"
else
    print_error "Failed to start TimescaleDB container"
    exit 1
fi

# Step 3: Wait for Database to be Ready
echo -e "\n${BLUE}=== Waiting for Database ===${NC}\n"

print_info "Waiting for database to be ready..."
MAX_WAIT=60
WAIT_COUNT=0
CONTAINER_NAME="log-ingestion-timescaledb"

while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    # Check if container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_error "Container ${CONTAINER_NAME} is not running"
        exit 1
    fi
    
    # Check if database is ready using pg_isready
    if docker exec $CONTAINER_NAME pg_isready -U postgres >/dev/null 2>&1; then
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
    print_info "Check container logs with: docker logs ${CONTAINER_NAME}"
    exit 1
fi

# Step 4: Run Migrations
echo -e "\n${BLUE}=== Running Migrations ===${NC}\n"

print_info "Running database migrations..."
if $DOCKER_COMPOSE exec -T timescaledb psql -U postgres -d logs < migrations/001_create_logs_table.sql >/dev/null 2>&1; then
    print_success "Migrations completed successfully"
else
    # Check if it's just a "table already exists" error (idempotent)
    MIGRATION_OUTPUT=$($DOCKER_COMPOSE exec -T timescaledb psql -U postgres -d logs < migrations/001_create_logs_table.sql 2>&1)
    if echo "$MIGRATION_OUTPUT" | grep -q "already exists\|duplicate\|ERROR"; then
        print_warning "Migrations may have already been applied (this is okay)"
    else
        print_error "Migration failed. Output:"
        echo "$MIGRATION_OUTPUT"
        exit 1
    fi
fi

# Step 5: Start Server
echo -e "\n${BLUE}=== Starting Server ===${NC}\n"

# Get the network name that the database container is on
NETWORK_NAME=$(docker inspect --format='{{range $net, $conf := .NetworkSettings.Networks}}{{$net}}{{end}}' $CONTAINER_NAME 2>/dev/null | head -n1)

if [ -z "$NETWORK_NAME" ]; then
    print_error "Could not determine network for database container"
    exit 1
fi

# Build Docker image
print_info "Building server Docker image..."
BUILD_OUTPUT=$(docker build -t log-ingestion-server:latest . 2>&1)
BUILD_EXIT_CODE=$?

if [ $BUILD_EXIT_CODE -eq 0 ]; then
    print_success "Server image built successfully"
else
    print_error "Failed to build server image"
    echo ""
    echo "Build output:"
    echo "$BUILD_OUTPUT"
    exit 1
fi

# Determine server container name
SERVER_CONTAINER_NAME="log-ingestion-server"

# Clean up any existing server container
if docker ps -a --format '{{.Names}}' | grep -q "^${SERVER_CONTAINER_NAME}$"; then
    print_info "Removing existing server container..."
    docker rm -f $SERVER_CONTAINER_NAME >/dev/null 2>&1
fi

print_success "All prerequisites met. Starting server..."
print_info "Server will run on http://localhost:8080"
print_info "Press Ctrl+C to stop the server\n"

# Function to cleanup on exit
cleanup() {
    echo ""
    print_info "Stopping server container..."
    # Try to stop the container (may already be stopped/removed with --rm)
    docker stop $SERVER_CONTAINER_NAME >/dev/null 2>&1 || true
    print_success "Server stopped"
    exit 0
}

# Trap Ctrl+C and call cleanup function
trap cleanup SIGINT SIGTERM

# Run the server container
# Using --rm so container is automatically removed when it stops
docker run --rm \
    --name $SERVER_CONTAINER_NAME \
    --network $NETWORK_NAME \
    -p 8080:8080 \
    -e LOG_INGESTION_SERVER_HOST=0.0.0.0 \
    -e LOG_INGESTION_SERVER_PORT=8080 \
    -e LOG_INGESTION_DB_HOST=$CONTAINER_NAME \
    -e LOG_INGESTION_DB_PORT=5432 \
    -e LOG_INGESTION_DB_USER=postgres \
    -e LOG_INGESTION_DB_PASSWORD=postgres \
    -e LOG_INGESTION_DB_NAME=logs \
    -e LOG_INGESTION_DB_SSLMODE=disable \
    -e LOG_INGESTION_BATCH_SIZE=1000 \
    -e LOG_INGESTION_BATCH_FLUSH_INTERVAL=5s \
    -e LOG_INGESTION_RATELIMIT_ENABLED=true \
    -e LOG_INGESTION_RATELIMIT_DEFAULT_RPS=100 \
    -e LOG_INGESTION_RATELIMIT_BURST=200 \
    log-ingestion-server:latest

# If we get here, the container exited
cleanup


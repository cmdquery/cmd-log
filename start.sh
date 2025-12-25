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

# Variables for process management
FRONTEND_PID=""
BACKEND_CONTAINER="log-ingestion-app"

# Function to cleanup on exit
cleanup() {
    echo ""
    print_info "Shutting down services..."
    
    # Kill frontend dev server if running
    if [ ! -z "$FRONTEND_PID" ] && kill -0 $FRONTEND_PID 2>/dev/null; then
        print_info "Stopping frontend dev server (PID: $FRONTEND_PID)..."
        # Kill the process and its children
        kill -TERM $FRONTEND_PID 2>/dev/null || true
        sleep 1
        # Force kill if still running
        kill -KILL $FRONTEND_PID 2>/dev/null || true
        wait $FRONTEND_PID 2>/dev/null || true
    fi
    
    # Kill any remaining node/npm processes related to our frontend
    pkill -f "vite.*5173" 2>/dev/null || true
    
    # Stop backend Docker container
    print_info "Stopping backend server..."
    if [ ! -z "$DOCKER_COMPOSE" ] && docker ps --format '{{.Names}}' | grep -q "^${BACKEND_CONTAINER}$"; then
        $DOCKER_COMPOSE stop app >/dev/null 2>&1 || true
        $DOCKER_COMPOSE rm -f app >/dev/null 2>&1 || true
    fi
    
    print_success "All services stopped"
    exit 0
}

# Trap Ctrl+C and call cleanup function
trap cleanup SIGINT SIGTERM

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

# Check Node.js
if ! command_exists node; then
    print_error "Node.js is not installed. Please install Node.js 18 or later."
    exit 1
fi
NODE_VERSION=$(node --version)
print_success "Node.js is installed ($NODE_VERSION)"

# Check npm
if ! command_exists npm; then
    print_error "npm is not installed. Please install npm."
    exit 1
fi
NPM_VERSION=$(npm --version)
print_success "npm is installed (v$NPM_VERSION)"

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
MIGRATION_OUTPUT=$($DOCKER_COMPOSE exec -T timescaledb psql -U postgres -d logs < migrations/001_create_logs_table.sql 2>&1)
MIGRATION_EXIT_CODE=$?

if [ $MIGRATION_EXIT_CODE -eq 0 ]; then
    print_success "Migrations completed successfully"
else
    # Check if it's just a "table already exists" error (idempotent)
    if echo "$MIGRATION_OUTPUT" | grep -q "already exists\|duplicate"; then
        print_warning "Migrations may have already been applied (this is okay)"
    else
        print_error "Migration failed. Output:"
        echo "$MIGRATION_OUTPUT"
        exit 1
    fi
fi

# Step 5: Setup Frontend
echo -e "\n${BLUE}=== Setting Up Frontend ===${NC}\n"

# Check if node_modules exists
if [ ! -d "web/node_modules" ]; then
    print_info "Installing frontend dependencies..."
    cd web
    if npm install; then
        print_success "Frontend dependencies installed"
    else
        print_error "Failed to install frontend dependencies"
        exit 1
    fi
    cd ..
else
    print_success "Frontend dependencies already installed"
fi

# Step 6: Start Frontend Dev Server
echo -e "\n${BLUE}=== Starting Frontend Dev Server ===${NC}\n"

print_info "Starting frontend dev server on http://localhost:5173"
cd web
# Start frontend in background with output to log file
npm run dev > /tmp/frontend.log 2>&1 &
FRONTEND_PID=$!
cd ..

# Wait a moment for the server to start
sleep 3

# Check if frontend server is still running
if ! kill -0 $FRONTEND_PID 2>/dev/null; then
    print_error "Frontend dev server failed to start"
    echo "Frontend logs:"
    cat /tmp/frontend.log 2>/dev/null || true
    exit 1
fi

print_success "Frontend dev server started (PID: $FRONTEND_PID)"
print_info "Frontend running at http://localhost:5173"
print_info "Frontend logs: tail -f /tmp/frontend.log"

# Step 7: Build and Start Backend Server
echo -e "\n${BLUE}=== Building and Starting Backend Server ===${NC}\n"

print_info "Building backend Docker image..."
if $DOCKER_COMPOSE build app >/dev/null 2>&1; then
    print_success "Backend Docker image built"
else
    print_error "Failed to build backend Docker image"
    exit 1
fi

print_info "Starting backend server on http://localhost:8080"
print_info "Press Ctrl+C to stop all services"
echo ""
print_info "Services:"
print_info "  - Frontend: http://localhost:5173 (background, logs: /tmp/frontend.log)"
print_info "  - Backend:  http://localhost:8080 (Docker container, foreground)"
echo ""

# Run backend in foreground - this will block until Ctrl+C
# Frontend continues running in background
# Use --no-deps to avoid restarting timescaledb, and remove container on exit
$DOCKER_COMPOSE up --no-deps app

# If we get here, backend exited (or was interrupted)
# Cleanup will be called by trap

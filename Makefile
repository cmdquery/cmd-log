.PHONY: help build run test clean docker-up docker-down docker-check migrate

# Check if Docker daemon is running
check_docker = @docker info >/dev/null 2>&1 || (echo "Error: Docker daemon is not running. Please start Docker Desktop and try again." && exit 1)

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build the application
	go build -o bin/server ./cmd/server

run: ## Run the application
	go run ./cmd/server

test: ## Run tests
	go test ./...

clean: ## Clean build artifacts
	rm -rf bin/

docker-check: ## Check if Docker daemon is running
	@docker info >/dev/null 2>&1 && echo "✓ Docker daemon is running" || (echo "✗ Docker daemon is not running. Please start Docker Desktop." && exit 1)

docker-up: ## Start Docker containers (TimescaleDB)
	$(check_docker)
	docker-compose up -d

docker-down: ## Stop Docker containers
	docker-compose down

migrate: ## Run database migrations
	@echo "Running migrations..."
	@docker-compose exec -T timescaledb psql -U postgres -d logs < migrations/001_create_logs_table.sql || \
	psql -h localhost -U postgres -d logs -f migrations/001_create_logs_table.sql

setup: docker-up migrate ## Setup development environment


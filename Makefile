.PHONY: help build run test clean docker-up docker-down migrate

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

docker-up: ## Start Docker containers (TimescaleDB)
	docker-compose up -d

docker-down: ## Stop Docker containers
	docker-compose down

migrate: ## Run database migrations
	@echo "Running migrations..."
	@docker-compose exec -T timescaledb psql -U postgres -d logs < migrations/001_create_logs_table.sql || \
	psql -h localhost -U postgres -d logs -f migrations/001_create_logs_table.sql

setup: docker-up migrate ## Setup development environment


.PHONY: help build build-frontend run dev test clean docker-up docker-down docker-check migrate deploy deploy-quick deploy-status deploy-logs env

# Check if Docker daemon is running
check_docker = @docker info >/dev/null 2>&1 || (echo "Error: Docker daemon is not running. Please start Docker Desktop and try again." && exit 1)

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build-frontend: ## Build the Vue frontend
	@echo "Building frontend..."
	@cd web && npm install && npm run build

build: build-frontend ## Build the application (includes frontend)
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
	@for f in $$(ls migrations/*.sql | sort); do \
		echo "  Applying $$(basename $$f)..."; \
		docker-compose exec -T timescaledb psql -U postgres -d logs < $$f 2>&1 || \
		psql -h localhost -U postgres -d logs -f $$f 2>&1; \
	done
	@echo "Migrations complete."

setup: docker-up migrate ## Setup development environment

dev: ## Start all services for local development (DB + migrations + frontend + backend)
	@chmod +x start.sh
	@./start.sh

env: ## Copy .env.example to .env for local development
	@if [ -f .env ]; then \
		echo "⚠ .env file already exists. Skipping..."; \
		echo "   To overwrite, delete .env first: rm .env"; \
	else \
		cp .env.example .env; \
		echo "✓ Created .env file from .env.example"; \
		echo "   Edit .env to configure your environment"; \
	fi

# Deployment targets
deploy: ## Deploy to DigitalOcean droplet (interactive)
	@chmod +x deploy/deploy.sh
	@./deploy/deploy.sh

deploy-quick: ## Quick deploy using DROPLET_IP and DROPLET_USER env vars
	@chmod +x deploy/deploy.sh
	@if [ -z "$$DROPLET_IP" ]; then \
		echo "Error: DROPLET_IP environment variable is required"; \
		echo "Usage: DROPLET_IP=1.2.3.4 DROPLET_USER=root make deploy-quick"; \
		exit 1; \
	fi
	@./deploy/deploy.sh --ip $$DROPLET_IP --user $${DROPLET_USER:-root}

deploy-status: ## Check deployment status on remote server
	@if [ -z "$$DROPLET_IP" ]; then \
		echo "Error: DROPLET_IP environment variable is required"; \
		echo "Usage: DROPLET_IP=1.2.3.4 DROPLET_USER=root make deploy-status"; \
		exit 1; \
	fi
	@echo "Checking deployment status on $$DROPLET_IP..."
	@ssh $${DROPLET_USER:-root}@$$DROPLET_IP "cd /opt/cmd-log && \
		(docker compose -f docker-compose.prod.yml ps 2>/dev/null || \
		 docker-compose -f docker-compose.prod.yml ps 2>/dev/null || \
		 echo 'Docker Compose not found or services not running')"

deploy-logs: ## View logs from remote deployment
	@if [ -z "$$DROPLET_IP" ]; then \
		echo "Error: DROPLET_IP environment variable is required"; \
		echo "Usage: DROPLET_IP=1.2.3.4 DROPLET_USER=root make deploy-logs"; \
		exit 1; \
	fi
	@ssh $${DROPLET_USER:-root}@$$DROPLET_IP "cd /opt/cmd-log && \
		(docker compose -f docker-compose.prod.yml logs -f 2>/dev/null || \
		 docker-compose -f docker-compose.prod.yml logs -f 2>/dev/null || \
		 echo 'Docker Compose not found')"
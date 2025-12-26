# Frontend build stage
FROM node:alpine AS frontend-builder

# Set working directory
WORKDIR /build

# Copy package files
COPY web/package.json web/package-lock.json ./web/

# Install dependencies
WORKDIR /build/web
RUN npm ci

# Copy web source files
COPY web/ .

# Build the Vue app
RUN npm run build

# Go build stage
FROM golang:1.21-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git

# Set working directory
WORKDIR /build

# Copy go mod files (both go.mod and go.sum)
COPY go.mod go.sum ./

# Download all dependencies to verify go.sum and populate module cache
RUN go mod download

# Copy source code
COPY . .

# Build the application
# CGO_ENABLED=0 creates a statically linked binary
# -ldflags="-s -w" strips debug symbols to reduce binary size
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo \
    -ldflags="-s -w" \
    -o server ./cmd/server

# Final stage
FROM alpine:latest

# Install CA certificates and wget for health checks
RUN apk --no-cache add ca-certificates tzdata wget

# Create non-root user for security
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

WORKDIR /app

# Copy binary from Go builder
COPY --from=builder /build/server .

# Copy built frontend from Node.js builder
COPY --from=frontend-builder /build/web/dist ./web/dist

# Change ownership to non-root user
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose default port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Run the application
CMD ["./server"]


package storage

import (
	"context"
	"fmt"
	"log-ingestion-service/pkg/models"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Repository handles database operations for logs
type Repository struct {
	pool *pgxpool.Pool
}

// NewRepository creates a new repository instance
func NewRepository(pool *pgxpool.Pool) *Repository {
	return &Repository{pool: pool}
}

// InsertLog inserts a single log entry
func (r *Repository) InsertLog(ctx context.Context, logEntry *models.LogEntry) error {
	query := `
		INSERT INTO logs (timestamp, service, level, message, metadata)
		VALUES ($1, $2, $3, $4, $5)
	`
	
	_, err := r.pool.Exec(ctx, query,
		logEntry.Timestamp,
		logEntry.Service,
		logEntry.Level,
		logEntry.Message,
		logEntry.Metadata,
	)
	
	return err
}

// InsertBatch inserts multiple log entries in a single transaction
func (r *Repository) InsertBatch(ctx context.Context, logEntries []models.LogEntry) error {
	if len(logEntries) == 0 {
		return nil
	}
	
	query := `
		INSERT INTO logs (timestamp, service, level, message, metadata)
		VALUES ($1, $2, $3, $4, $5)
	`
	
	batch := &pgx.Batch{}
	for _, logEntry := range logEntries {
		batch.Queue(query,
			logEntry.Timestamp,
			logEntry.Service,
			logEntry.Level,
			logEntry.Message,
			logEntry.Metadata,
		)
	}
	
	br := r.pool.SendBatch(ctx, batch)
	defer br.Close()
	
	for i := 0; i < len(logEntries); i++ {
		_, err := br.Exec()
		if err != nil {
			return fmt.Errorf("error inserting log entry %d: %w", i, err)
		}
	}
	
	return nil
}

// HealthCheck checks if the database connection is healthy
func (r *Repository) HealthCheck(ctx context.Context) error {
	var result int
	err := r.pool.QueryRow(ctx, "SELECT 1").Scan(&result)
	if err != nil {
		return fmt.Errorf("database health check failed: %w", err)
	}
	return nil
}


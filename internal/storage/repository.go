package storage

import (
	"context"
	"fmt"
	"log-ingestion-service/pkg/models"
	"time"

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

// GetTotalLogCount returns the total number of logs
func (r *Repository) GetTotalLogCount(ctx context.Context) (int64, error) {
	var count int64
	err := r.pool.QueryRow(ctx, "SELECT COUNT(*) FROM logs").Scan(&count)
	return count, err
}

// LogStats represents aggregated log statistics
type LogStats struct {
	TotalLogs    int64            `json:"total_logs"`
	ByService    map[string]int64 `json:"by_service"`
	ByLevel      map[string]int64 `json:"by_level"`
	ErrorCount   int64            `json:"error_count"`
	RecentErrors int64            `json:"recent_errors"`
}

// GetLogStats returns aggregated statistics for a time range
func (r *Repository) GetLogStats(ctx context.Context, timeRange time.Duration) (*LogStats, error) {
	since := time.Now().Add(-timeRange)
	
	stats := &LogStats{
		ByService: make(map[string]int64),
		ByLevel:   make(map[string]int64),
	}
	
	// Total logs
	err := r.pool.QueryRow(ctx, "SELECT COUNT(*) FROM logs WHERE timestamp >= $1", since).Scan(&stats.TotalLogs)
	if err != nil {
		return nil, fmt.Errorf("error getting total logs: %w", err)
	}
	
	// By service
	rows, err := r.pool.Query(ctx, `
		SELECT service, COUNT(*) 
		FROM logs 
		WHERE timestamp >= $1 
		GROUP BY service 
		ORDER BY COUNT(*) DESC
	`, since)
	if err != nil {
		return nil, fmt.Errorf("error getting logs by service: %w", err)
	}
	defer rows.Close()
	
	for rows.Next() {
		var service string
		var count int64
		if err := rows.Scan(&service, &count); err != nil {
			return nil, err
		}
		stats.ByService[service] = count
	}
	
	// By level
	rows, err = r.pool.Query(ctx, `
		SELECT level, COUNT(*) 
		FROM logs 
		WHERE timestamp >= $1 
		GROUP BY level 
		ORDER BY COUNT(*) DESC
	`, since)
	if err != nil {
		return nil, fmt.Errorf("error getting logs by level: %w", err)
	}
	defer rows.Close()
	
	for rows.Next() {
		var level string
		var count int64
		if err := rows.Scan(&level, &count); err != nil {
			return nil, err
		}
		stats.ByLevel[level] = count
		if level == "ERROR" || level == "FATAL" || level == "CRITICAL" {
			stats.ErrorCount += count
		}
	}
	
	// Recent errors (last hour)
	recentSince := time.Now().Add(-1 * time.Hour)
	err = r.pool.QueryRow(ctx, `
		SELECT COUNT(*) 
		FROM logs 
		WHERE timestamp >= $1 
		AND level IN ('ERROR', 'FATAL', 'CRITICAL')
	`, recentSince).Scan(&stats.RecentErrors)
	if err != nil {
		return nil, fmt.Errorf("error getting recent errors: %w", err)
	}
	
	return stats, nil
}

// GetRecentLogs returns recent log entries
func (r *Repository) GetRecentLogs(ctx context.Context, limit int) ([]models.LogEntry, error) {
	query := `
		SELECT id, timestamp, service, level, message, metadata
		FROM logs
		ORDER BY timestamp DESC
		LIMIT $1
	`
	
	rows, err := r.pool.Query(ctx, query, limit)
	if err != nil {
		return nil, fmt.Errorf("error getting recent logs: %w", err)
	}
	defer rows.Close()
	
	var logs []models.LogEntry
	for rows.Next() {
		var log models.LogEntry
		var metadata map[string]interface{}
		err := rows.Scan(&log.ID, &log.Timestamp, &log.Service, &log.Level, &log.Message, &metadata)
		if err != nil {
			return nil, err
		}
		log.Metadata = metadata
		logs = append(logs, log)
	}
	
	return logs, nil
}

// GetErrorLogs returns recent error logs
func (r *Repository) GetErrorLogs(ctx context.Context, limit int, timeRange time.Duration) ([]models.LogEntry, error) {
	since := time.Now().Add(-timeRange)
	query := `
		SELECT id, timestamp, service, level, message, metadata
		FROM logs
		WHERE timestamp >= $1
		AND level IN ('ERROR', 'FATAL', 'CRITICAL')
		ORDER BY timestamp DESC
		LIMIT $2
	`
	
	rows, err := r.pool.Query(ctx, query, since, limit)
	if err != nil {
		return nil, fmt.Errorf("error getting error logs: %w", err)
	}
	defer rows.Close()
	
	var logs []models.LogEntry
	for rows.Next() {
		var log models.LogEntry
		var metadata map[string]interface{}
		err := rows.Scan(&log.ID, &log.Timestamp, &log.Service, &log.Level, &log.Message, &metadata)
		if err != nil {
			return nil, err
		}
		log.Metadata = metadata
		logs = append(logs, log)
	}
	
	return logs, nil
}

// GetLogByID returns a single log entry by ID
func (r *Repository) GetLogByID(ctx context.Context, id int64) (*models.LogEntry, error) {
	query := `
		SELECT id, timestamp, service, level, message, metadata
		FROM logs
		WHERE id = $1
	`
	
	var log models.LogEntry
	var metadata map[string]interface{}
	err := r.pool.QueryRow(ctx, query, id).Scan(&log.ID, &log.Timestamp, &log.Service, &log.Level, &log.Message, &metadata)
	if err != nil {
		return nil, fmt.Errorf("error getting log by ID: %w", err)
	}
	log.Metadata = metadata
	
	return &log, nil
}

// APIKey represents an API key in the database
type APIKey struct {
	ID              int64     `json:"id"`
	Key             string    `json:"key"` // Only returned when creating
	Name            string    `json:"name"`
	Description     string    `json:"description"`
	CreatedAt       time.Time `json:"created_at"`
	IsActive        bool      `json:"is_active"`
	CreatedByUserID *int64    `json:"created_by_user_id"`
}

// TimeSeriesPoint represents a data point for time series charts
type TimeSeriesPoint struct {
	Time  time.Time `json:"time"`
	Count int64     `json:"count"`
}

// GetTimeSeriesData returns time series data for charts
func (r *Repository) GetTimeSeriesData(ctx context.Context, timeRange time.Duration, interval string) ([]TimeSeriesPoint, error) {
	since := time.Now().Add(-timeRange)
	
	// Validate interval (1m, 5m, 1h, etc.)
	var timeBucket string
	switch interval {
	case "1m":
		timeBucket = "1 minute"
	case "5m":
		timeBucket = "5 minutes"
	case "15m":
		timeBucket = "15 minutes"
	case "1h":
		timeBucket = "1 hour"
	default:
		timeBucket = "5 minutes"
	}
	
	query := fmt.Sprintf(`
		SELECT time_bucket('%s', timestamp) AS bucket, COUNT(*) as count
		FROM logs
		WHERE timestamp >= $1
		GROUP BY bucket
		ORDER BY bucket ASC
	`, timeBucket)
	
	rows, err := r.pool.Query(ctx, query, since)
	if err != nil {
		return nil, fmt.Errorf("error getting time series data: %w", err)
	}
	defer rows.Close()
	
	var points []TimeSeriesPoint
	for rows.Next() {
		var point TimeSeriesPoint
		err := rows.Scan(&point.Time, &point.Count)
		if err != nil {
			return nil, err
		}
		points = append(points, point)
	}
	
	return points, nil
}

// CreateAPIKey creates a new API key in the database
func (r *Repository) CreateAPIKey(ctx context.Context, name, description, key string, createdByUserID int64) (*APIKey, error) {
	query := `
		INSERT INTO api_keys (key, name, description, created_at, is_active, created_by_user_id)
		VALUES ($1, $2, $3, NOW(), TRUE, $4)
		RETURNING id, key, name, description, created_at, is_active, created_by_user_id
	`
	
	var apiKey APIKey
	err := r.pool.QueryRow(ctx, query, key, name, description, createdByUserID).Scan(
		&apiKey.ID,
		&apiKey.Key,
		&apiKey.Name,
		&apiKey.Description,
		&apiKey.CreatedAt,
		&apiKey.IsActive,
		&apiKey.CreatedByUserID,
	)
	if err != nil {
		return nil, fmt.Errorf("error creating API key: %w", err)
	}
	
	return &apiKey, nil
}

// ListAPIKeys returns API keys. If userID is nil, returns all keys (admin).
// If userID is provided, returns only keys created by that user.
func (r *Repository) ListAPIKeys(ctx context.Context, userID *int64) ([]APIKey, error) {
	var query string
	var args []interface{}

	if userID != nil {
		query = `
			SELECT id, name, description, created_at, is_active, created_by_user_id
			FROM api_keys
			WHERE created_by_user_id = $1
			ORDER BY created_at DESC
		`
		args = append(args, *userID)
	} else {
		query = `
			SELECT id, name, description, created_at, is_active, created_by_user_id
			FROM api_keys
			ORDER BY created_at DESC
		`
	}

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("error listing API keys: %w", err)
	}
	defer rows.Close()
	
	var keys []APIKey
	for rows.Next() {
		var key APIKey
		err := rows.Scan(
			&key.ID,
			&key.Name,
			&key.Description,
			&key.CreatedAt,
			&key.IsActive,
			&key.CreatedByUserID,
		)
		if err != nil {
			return nil, err
		}
		keys = append(keys, key)
	}
	
	return keys, nil
}

// DeleteAPIKey soft deletes an API key by setting is_active to false.
// If userID is provided, only deletes if the key belongs to that user.
// If userID is nil (admin), deletes any key regardless of ownership.
func (r *Repository) DeleteAPIKey(ctx context.Context, id int64, userID *int64) error {
	var query string
	var args []interface{}

	if userID != nil {
		query = `
			UPDATE api_keys
			SET is_active = FALSE
			WHERE id = $1 AND created_by_user_id = $2
		`
		args = []interface{}{id, *userID}
	} else {
		query = `
			UPDATE api_keys
			SET is_active = FALSE
			WHERE id = $1
		`
		args = []interface{}{id}
	}

	result, err := r.pool.Exec(ctx, query, args...)
	if err != nil {
		return fmt.Errorf("error deleting API key: %w", err)
	}
	
	if result.RowsAffected() == 0 {
		return fmt.Errorf("API key with id %d not found or not authorized", id)
	}
	
	return nil
}

// GetAPIKeyByValue checks if an API key exists and is active
func (r *Repository) GetAPIKeyByValue(ctx context.Context, key string) (bool, error) {
	var exists bool
	query := `
		SELECT EXISTS(
			SELECT 1 FROM api_keys
			WHERE key = $1 AND is_active = TRUE
		)
	`
	
	err := r.pool.QueryRow(ctx, query, key).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("error checking API key: %w", err)
	}
	
	return exists, nil
}

// GetAllActiveAPIKeys returns all active API key strings (for validation)
func (r *Repository) GetAllActiveAPIKeys(ctx context.Context) ([]string, error) {
	query := `
		SELECT key
		FROM api_keys
		WHERE is_active = TRUE
	`
	
	rows, err := r.pool.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("error getting active API keys: %w", err)
	}
	defer rows.Close()
	
	var keys []string
	for rows.Next() {
		var key string
		if err := rows.Scan(&key); err != nil {
			return nil, err
		}
		keys = append(keys, key)
	}
	
	return keys, nil
}
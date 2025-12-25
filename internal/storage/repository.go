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
		SELECT timestamp, service, level, message, metadata
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
		err := rows.Scan(&log.Timestamp, &log.Service, &log.Level, &log.Message, &metadata)
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
		SELECT timestamp, service, level, message, metadata
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
		err := rows.Scan(&log.Timestamp, &log.Service, &log.Level, &log.Message, &metadata)
		if err != nil {
			return nil, err
		}
		log.Metadata = metadata
		logs = append(logs, log)
	}
	
	return logs, nil
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


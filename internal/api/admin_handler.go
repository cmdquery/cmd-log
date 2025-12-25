package api

import (
	"context"
	"fmt"
	"log-ingestion-service/internal/batch"
	"log-ingestion-service/internal/storage"
	"log-ingestion-service/pkg/config"
	"log-ingestion-service/pkg/models"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

// AdminHandler handles admin web interface requests
type AdminHandler struct {
	repository *storage.Repository
	batcher    *batch.Batcher
	config     *config.Config
	startTime  time.Time
}

// NewAdminHandler creates a new admin handler
func NewAdminHandler(repo *storage.Repository, batcher *batch.Batcher, cfg *config.Config) *AdminHandler {
	return &AdminHandler{
		repository: repo,
		batcher:    batcher,
		config:     cfg,
		startTime:  time.Now(),
	}
}

// Dashboard renders the main admin dashboard
func (h *AdminHandler) Dashboard(c *gin.Context) {
	c.HTML(http.StatusOK, "dashboard.html", gin.H{
		"title": "Admin Dashboard",
	})
}

// Health returns detailed health status
func (h *AdminHandler) Health(c *gin.Context) {
	ctx := context.Background()
	
	// Check database health
	dbHealthy := true
	dbError := ""
	if err := h.repository.HealthCheck(ctx); err != nil {
		dbHealthy = false
		dbError = err.Error()
	}
	
	// Get batcher metrics
	batcherMetrics := h.batcher.GetMetrics()
	
	health := gin.H{
		"status": "healthy",
		"uptime": time.Since(h.startTime).String(),
		"database": gin.H{
			"healthy": dbHealthy,
			"error":   dbError,
		},
		"batcher": gin.H{
			"healthy":        batcherMetrics.ErrorCount == 0,
			"current_batch":  batcherMetrics.CurrentBatchSize,
			"total_processed": batcherMetrics.TotalProcessed,
			"flush_count":    batcherMetrics.FlushCount,
			"error_count":    batcherMetrics.ErrorCount,
			"uptime":         batcherMetrics.Uptime.String(),
		},
		"config": gin.H{
			"batch_size":        h.config.Batch.Size,
			"batch_flush_interval": h.config.Batch.FlushInterval.String(),
			"rate_limit_enabled": h.config.RateLimit.Enabled,
			"rate_limit_rps":    h.config.RateLimit.DefaultRPS,
		},
	}
	
	if !dbHealthy {
		health["status"] = "unhealthy"
	}
	
	if c.GetHeader("Accept") == "application/json" || c.Query("format") == "json" {
		c.JSON(http.StatusOK, health)
	} else {
		c.HTML(http.StatusOK, "health.html", gin.H{
			"title":  "Health Status",
			"health": health,
		})
	}
}

// Metrics returns service metrics
func (h *AdminHandler) Metrics(c *gin.Context) {
	ctx := context.Background()
	
	// Get time range from query (default: 1 hour)
	timeRangeStr := c.DefaultQuery("range", "1h")
	timeRange, err := time.ParseDuration(timeRangeStr)
	if err != nil {
		timeRange = 1 * time.Hour
	}
	
	// Get stats
	stats, err := h.repository.GetLogStats(ctx, timeRange)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to get stats",
			"details": err.Error(),
		})
		return
	}
	
	// Get batcher metrics
	batcherMetrics := h.batcher.GetMetrics()
	
	// Calculate logs per second
	var logsPerSecond float64
	if timeRange.Seconds() > 0 {
		logsPerSecond = float64(stats.TotalLogs) / timeRange.Seconds()
	}
	
	// Get time series data
	interval := c.DefaultQuery("interval", "5m")
	timeSeries, err := h.repository.GetTimeSeriesData(ctx, timeRange, interval)
	if err != nil {
		// Log error but don't fail the request
		timeSeries = []storage.TimeSeriesPoint{}
	}
	
	metrics := gin.H{
		"time_range": timeRange.String(),
		"logs": gin.H{
			"total":         stats.TotalLogs,
			"per_second":    logsPerSecond,
			"by_service":    stats.ByService,
			"by_level":      stats.ByLevel,
			"error_count":   stats.ErrorCount,
			"recent_errors": stats.RecentErrors,
		},
		"batcher": batcherMetrics,
		"time_series": timeSeries,
		"uptime": time.Since(h.startTime).String(),
	}
	
	c.JSON(http.StatusOK, metrics)
}

// Logs renders the recent logs page
func (h *AdminHandler) Logs(c *gin.Context) {
	c.HTML(http.StatusOK, "logs.html", gin.H{
		"title": "Recent Logs",
	})
}

// RecentLogs returns recent logs as JSON
func (h *AdminHandler) RecentLogs(c *gin.Context) {
	ctx := context.Background()
	
	limit := 100
	if limitStr := c.Query("limit"); limitStr != "" {
		if parsedLimit, err := parseInt(limitStr); err == nil && parsedLimit > 0 && parsedLimit <= 1000 {
			limit = parsedLimit
		}
	}
	
	logs, err := h.repository.GetRecentLogs(ctx, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to get recent logs",
			"details": err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{
		"logs": logs,
		"count": len(logs),
	})
}

// Stats returns aggregated statistics
func (h *AdminHandler) Stats(c *gin.Context) {
	ctx := context.Background()
	
	// Get time range from query (default: 24 hours)
	timeRangeStr := c.DefaultQuery("range", "24h")
	timeRange, err := time.ParseDuration(timeRangeStr)
	if err != nil {
		timeRange = 24 * time.Hour
	}
	
	// Get total count
	totalCount, err := h.repository.GetTotalLogCount(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to get total count",
			"details": err.Error(),
		})
		return
	}
	
	// Get stats
	stats, err := h.repository.GetLogStats(ctx, timeRange)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to get stats",
			"details": err.Error(),
		})
		return
	}
	
	// Get error logs
	errorLogs, err := h.repository.GetErrorLogs(ctx, 50, 1*time.Hour)
	if err != nil {
		errorLogs = []models.LogEntry{}
	}
	
	response := gin.H{
		"total_logs": totalCount,
		"time_range": timeRange.String(),
		"stats": stats,
		"recent_errors": errorLogs,
	}
	
	c.JSON(http.StatusOK, response)
}

// Helper function to parse integer
func parseInt(s string) (int, error) {
	var result int
	_, err := fmt.Sscanf(s, "%d", &result)
	return result, err
}


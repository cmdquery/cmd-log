package api

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"log"
	"log-ingestion-service/internal/auth"
	"log-ingestion-service/internal/batch"
	"log-ingestion-service/internal/storage"
	"log-ingestion-service/pkg/config"
	"log-ingestion-service/pkg/models"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
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
	
	c.JSON(http.StatusOK, health)
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

// GetLogByID returns a single log entry by ID
func (h *AdminHandler) GetLogByID(c *gin.Context) {
	ctx := context.Background()
	
	idStr := c.Param("id")
	var id int64
	if _, err := fmt.Sscanf(idStr, "%d", &id); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid log ID",
		})
		return
	}
	
	log, err := h.repository.GetLogByID(ctx, id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Log not found",
			"details": err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusOK, log)
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

// RegisterRequest represents the request to register a new user
type RegisterRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Name     string `json:"name" binding:"required"`
	Password string `json:"password" binding:"required,min=6"`
}

// Register handles user registration
func (h *AdminHandler) Register(c *gin.Context) {
	var req RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "Invalid request",
			"details": err.Error(),
		})
		return
	}

	req.Email = strings.ToLower(strings.TrimSpace(req.Email))
	req.Name = strings.TrimSpace(req.Name)

	// Check if user already exists
	ctx := context.Background()
	existing, _ := h.repository.GetUserByEmail(ctx, req.Email)
	if existing != nil {
		c.JSON(http.StatusConflict, gin.H{
			"error": "A user with this email already exists",
		})
		return
	}

	// Hash password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		log.Printf("ERROR: Failed to hash password: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to create account",
		})
		return
	}

	// Create user
	user, err := h.repository.CreateUserWithPassword(ctx, req.Email, req.Name, string(hashedPassword))
	if err != nil {
		log.Printf("ERROR: Failed to create user: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to create account",
			"details": err.Error(),
		})
		return
	}

	log.Printf("INFO: User registered successfully: ID=%d, Email=%s", user.ID, user.Email)

	c.JSON(http.StatusCreated, gin.H{
		"success": true,
		"message": "Account created successfully",
		"user": gin.H{
			"id":    user.ID,
			"email": user.Email,
			"name":  user.Name,
		},
	})
}

// LoginRequest represents the request to log in
type LoginRequest struct {
	Email    string `json:"email" binding:"required"`
	Password string `json:"password" binding:"required"`
}

// Login handles user login with email and password
func (h *AdminHandler) Login(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "Invalid request",
			"details": err.Error(),
		})
		return
	}

	req.Email = strings.ToLower(strings.TrimSpace(req.Email))

	// Look up user by email
	ctx := context.Background()
	user, err := h.repository.GetUserByEmail(ctx, req.Email)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{
			"success": false,
			"error":   "Invalid email or password",
		})
		return
	}

	// Verify password
	if user.PasswordHash == nil {
		c.JSON(http.StatusUnauthorized, gin.H{
			"success": false,
			"error":   "Invalid email or password",
		})
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(*user.PasswordHash), []byte(req.Password)); err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{
			"success": false,
			"error":   "Invalid email or password",
		})
		return
	}

	// Generate JWT
	token, err := auth.GenerateJWT(h.config.Auth.JWTSecret, user.ID, user.Email, user.Name)
	if err != nil {
		log.Printf("ERROR: Failed to generate JWT: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to generate authentication token",
		})
		return
	}

	// Set auth cookie (7 days, httpOnly=false so JS can read it)
	c.SetCookie("auth_token", token, 86400*7, "/", "", false, false)

	log.Printf("INFO: User logged in: ID=%d, Email=%s", user.ID, user.Email)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Login successful",
		"token":   token,
		"user": gin.H{
			"id":    user.ID,
			"email": user.Email,
			"name":  user.Name,
		},
	})
}

// ListAPIKeys returns all API keys as JSON (keys are masked for security)
func (h *AdminHandler) ListAPIKeys(c *gin.Context) {
	ctx := context.Background()
	
	keys, err := h.repository.ListAPIKeys(ctx)
	if err != nil {
		log.Printf("ERROR: Failed to list API keys: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to list API keys",
			"details": err.Error(),
		})
		return
	}
	
	// Keys are returned without the actual key value for security
	responseKeys := make([]gin.H, len(keys))
	for i, key := range keys {
		responseKeys[i] = gin.H{
			"id":          key.ID,
			"name":        key.Name,
			"description": key.Description,
			"created_at":  key.CreatedAt,
			"is_active":   key.IsActive,
		}
	}
	
	c.JSON(http.StatusOK, gin.H{
		"keys": responseKeys,
	})
}

// CreateAPIKeyRequest represents the request to create a new API key
type CreateAPIKeyRequest struct {
	Name        string `json:"name" binding:"required"`
	Description string `json:"description"`
}

// CreateAPIKey creates a new API key
func (h *AdminHandler) CreateAPIKey(c *gin.Context) {
	var req CreateAPIKeyRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		log.Printf("ERROR: Invalid request to create API key: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request",
			"details": err.Error(),
		})
		return
	}
	
	// Generate a secure random API key (32 bytes, base64 encoded = ~44 chars)
	keyBytes := make([]byte, 32)
	if _, err := rand.Read(keyBytes); err != nil {
		log.Printf("ERROR: Failed to generate random bytes for API key: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to generate API key",
			"details": err.Error(),
		})
		return
	}
	apiKey := base64.URLEncoding.EncodeToString(keyBytes)
	
	ctx := context.Background()
	createdKey, err := h.repository.CreateAPIKey(ctx, req.Name, req.Description, apiKey)
	if err != nil {
		log.Printf("ERROR: Failed to create API key in database: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to create API key",
			"details": err.Error(),
		})
		return
	}
	
	log.Printf("INFO: API key created successfully: ID=%d, Name=%s", createdKey.ID, createdKey.Name)
	
	// Return the full key only once (for the user to copy)
	c.JSON(http.StatusOK, gin.H{
		"id":          createdKey.ID,
		"key":         createdKey.Key,
		"name":        createdKey.Name,
		"description": createdKey.Description,
		"created_at":  createdKey.CreatedAt,
		"is_active":   createdKey.IsActive,
		"message":     "API key created successfully. Please copy it now as it won't be shown again.",
	})
}

// DeleteAPIKey deletes an API key (soft delete)
func (h *AdminHandler) DeleteAPIKey(c *gin.Context) {
	idStr := c.Param("id")
	var id int64
	if _, err := fmt.Sscanf(idStr, "%d", &id); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid API key ID",
		})
		return
	}
	
	ctx := context.Background()
	if err := h.repository.DeleteAPIKey(ctx, id); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to delete API key",
			"details": err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{
		"message": "API key deleted successfully",
	})
}

// Helper function to parse integer
func parseInt(s string) (int, error) {
	var result int
	_, err := fmt.Sscanf(s, "%d", &result)
	return result, err
}


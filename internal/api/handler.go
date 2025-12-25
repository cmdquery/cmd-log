package api

import (
	"fmt"
	"log-ingestion-service/internal/batch"
	"log-ingestion-service/internal/parser"
	"log-ingestion-service/internal/validator"
	"log-ingestion-service/pkg/models"
	"net/http"

	"github.com/gin-gonic/gin"
)

// Handler handles HTTP requests
type Handler struct {
	parser    *parser.AutoParser
	validator *validator.Validator
	batcher   *batch.Batcher
}

// NewHandler creates a new handler
func NewHandler(batcher *batch.Batcher) *Handler {
	return &Handler{
		parser:    parser.NewAutoParser(),
		validator: validator.NewValidator(),
		batcher:   batcher,
	}
}

// IngestLog handles single log ingestion
func (h *Handler) IngestLog(c *gin.Context) {
	var req models.LogRequest
	
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request body",
			"details": err.Error(),
		})
		return
	}
	
	// Validate
	if err := h.validator.Validate(&req.Log); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Validation failed",
			"details": err.Error(),
		})
		return
	}
	
	// Sanitize
	h.validator.Sanitize(&req.Log)
	
	// Add to batch
	if err := h.batcher.Add(req.Log); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to process log",
			"details": err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusAccepted, gin.H{
		"message": "Log accepted",
	})
}

// IngestBatch handles batch log ingestion
func (h *Handler) IngestBatch(c *gin.Context) {
	var req models.BatchLogRequest
	
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request body",
			"details": err.Error(),
		})
		return
	}
	
	if len(req.Logs) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Empty batch",
		})
		return
	}
	
	// Validate and sanitize all logs
	validLogs := make([]models.LogEntry, 0, len(req.Logs))
	var validationErrors []string
	
	for i, logEntry := range req.Logs {
		if err := h.validator.Validate(&logEntry); err != nil {
			validationErrors = append(validationErrors, 
				fmt.Sprintf("Log entry %d validation failed: %s", i, err.Error()))
			continue
		}
		
		h.validator.Sanitize(&logEntry)
		validLogs = append(validLogs, logEntry)
	}
	
	// Add valid logs to batch
	if len(validLogs) > 0 {
		if err := h.batcher.AddBatch(validLogs); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Failed to process logs",
				"details": err.Error(),
			})
			return
		}
	}
	
	response := gin.H{
		"message": "Batch processed",
		"accepted": len(validLogs),
		"total": len(req.Logs),
	}
	
	if len(validationErrors) > 0 {
		response["errors"] = validationErrors
		response["rejected"] = len(validationErrors)
	}
	
	c.JSON(http.StatusAccepted, response)
}

// Health handles health check requests
func (h *Handler) Health(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status": "healthy",
	})
}


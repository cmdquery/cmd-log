package api

import (
	"log-ingestion-service/internal/auth"
	"log-ingestion-service/internal/middleware"
	"log-ingestion-service/pkg/config"

	"github.com/gin-gonic/gin"
)

// SetupRoutes configures all API routes
func SetupRoutes(router *gin.Engine, handler *Handler, cfg *config.Config) {
	// Root landing page (no auth required)
	router.GET("/", handler.Index)
	
	// Health check (no auth required)
	router.GET("/health", handler.Health)
	
	// API v1 routes
	v1 := router.Group("/api/v1")
	{
		// Apply authentication middleware
		v1.Use(auth.APIKeyAuth(&cfg.Auth))
		
		// Apply rate limiting middleware
		v1.Use(middleware.RateLimit(&cfg.RateLimit))
		
		// Log ingestion endpoints
		v1.POST("/logs", handler.IngestLog)
		v1.POST("/logs/batch", handler.IngestBatch)
	}
}


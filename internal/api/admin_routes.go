package api

import (
	"log-ingestion-service/internal/auth"
	"log-ingestion-service/pkg/config"

	"github.com/gin-gonic/gin"
)

// SetupAdminRoutes configures all admin routes
func SetupAdminRoutes(router *gin.Engine, adminHandler *AdminHandler, cfg *config.Config) {
	// Login route (no auth required)
	router.POST("/admin/login", adminHandler.Login)
	
	// Admin routes group
	admin := router.Group("/admin")
	{
		// Apply admin authentication middleware
		admin.Use(auth.AdminAuth(&cfg.Auth))
		
		// Health status (JSON endpoint)
		admin.GET("/health", adminHandler.Health)
		
		// Metrics endpoint
		admin.GET("/metrics", adminHandler.Metrics)
		
		// Recent logs JSON endpoint
		admin.GET("/logs/recent", adminHandler.RecentLogs)
		
		// Statistics endpoint
		admin.GET("/stats", adminHandler.Stats)
		
		// API Keys JSON endpoints
		admin.GET("/api/keys", adminHandler.ListAPIKeys)
		admin.POST("/api/keys", adminHandler.CreateAPIKey)
		admin.DELETE("/api/keys/:id", adminHandler.DeleteAPIKey)
	}
}


package api

import (
	"log-ingestion-service/internal/auth"
	"log-ingestion-service/pkg/config"

	"github.com/gin-gonic/gin"
)

// SetupAdminRoutes configures all admin routes
func SetupAdminRoutes(router *gin.Engine, adminHandler *AdminHandler, cfg *config.Config) {
	// Admin routes group
	admin := router.Group("/admin")
	{
		// Apply admin authentication middleware
		admin.Use(auth.AdminAuth(&cfg.Auth))
		
		// Dashboard (main page)
		admin.GET("", adminHandler.Dashboard)
		admin.GET("/", adminHandler.Dashboard)
		
		// Health status
		admin.GET("/health", adminHandler.Health)
		
		// Metrics endpoint
		admin.GET("/metrics", adminHandler.Metrics)
		
		// Logs page
		admin.GET("/logs", adminHandler.Logs)
		
		// Recent logs JSON endpoint
		admin.GET("/logs/recent", adminHandler.RecentLogs)
		
		// Statistics endpoint
		admin.GET("/stats", adminHandler.Stats)
	}
}


package api

import (
	"log-ingestion-service/internal/auth"
	"log-ingestion-service/pkg/config"

	"github.com/gin-gonic/gin"
)

// SetupAdminRoutes configures all admin routes
func SetupAdminRoutes(router *gin.Engine, adminHandler *AdminHandler, cfg *config.Config) {
	// Auth routes (no auth required)
	authGroup := router.Group("/auth")
	{
		authGroup.POST("/register", adminHandler.Register)
		authGroup.POST("/login", adminHandler.Login)
	}

	// Keep legacy login route for backward compatibility
	router.POST("/admin/login", adminHandler.Login)

	// Admin routes group (JWT-protected)
	admin := router.Group("/admin")
	{
		admin.Use(auth.JWTAuth(cfg.Auth.JWTSecret))

		// Health status (JSON endpoint)
		admin.GET("/health", adminHandler.Health)

		// Metrics endpoint
		admin.GET("/metrics", adminHandler.Metrics)

		// Recent logs JSON endpoint
		admin.GET("/logs/recent", adminHandler.RecentLogs)

		// Get log by ID endpoint
		admin.GET("/logs/:id", adminHandler.GetLogByID)

		// Statistics endpoint
		admin.GET("/stats", adminHandler.Stats)

		// API Keys JSON endpoints
		admin.GET("/api/keys", adminHandler.ListAPIKeys)
		admin.POST("/api/keys", adminHandler.CreateAPIKey)
		admin.DELETE("/api/keys/:id", adminHandler.DeleteAPIKey)
	}
}


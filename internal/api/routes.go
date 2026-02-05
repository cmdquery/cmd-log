package api

import (
	"log-ingestion-service/internal/auth"
	"log-ingestion-service/internal/middleware"
	"log-ingestion-service/pkg/config"

	"github.com/gin-gonic/gin"
)

// SetupRoutes configures all API routes
func SetupRoutes(router *gin.Engine, handler *Handler, keyManager *auth.KeyManager, cfg *config.Config) {
	// Health check (no auth required)
	router.GET("/health", handler.Health)
	
	// API v1 routes
	v1 := router.Group("/api/v1")
	{
		// Apply authentication middleware
		v1.Use(auth.APIKeyAuth(keyManager))
		
		// Apply rate limiting middleware
		v1.Use(middleware.RateLimit(&cfg.RateLimit))
		
		// Log ingestion endpoints
		v1.POST("/logs", handler.IngestLog)
		v1.POST("/logs/batch", handler.IngestBatch)
	}
}

// SetupFaultRoutes configures fault-related API routes
func SetupFaultRoutes(router *gin.Engine, faultHandler *FaultHandler, keyManager *auth.KeyManager, cfg *config.Config) {
	// API v1 routes
	v1 := router.Group("/api/v1")
	{
		// Apply combined auth middleware (accepts API key OR JWT token)
		v1.Use(auth.CombinedAuth(keyManager, cfg.Auth.JWTSecret))
		
		// Apply rate limiting middleware
		v1.Use(middleware.RateLimit(&cfg.RateLimit))
		
		// Notice ingestion (Honeybadger-compatible)
		v1.POST("/notices", faultHandler.IngestNotice)
		
		// Fault endpoints
		v1.GET("/faults", faultHandler.ListFaults)
		v1.GET("/faults/:id", faultHandler.GetFault)
		v1.PATCH("/faults/:id", faultHandler.UpdateFault)
		v1.DELETE("/faults/:id", faultHandler.DeleteFault)
		
		// Fault actions
		v1.POST("/faults/:id/resolve", faultHandler.ResolveFault)
		v1.POST("/faults/:id/unresolve", faultHandler.UnresolveFault)
		v1.POST("/faults/:id/ignore", faultHandler.IgnoreFault)
		v1.POST("/faults/:id/assign", faultHandler.AssignFault)
		v1.POST("/faults/:id/tags", faultHandler.AddFaultTags)
		v1.PUT("/faults/:id/tags", faultHandler.ReplaceFaultTags)
		v1.POST("/faults/:id/merge", faultHandler.MergeFaults)
		
		// Fault sub-resources
		v1.GET("/faults/:id/notices", faultHandler.GetFaultNotices)
		v1.GET("/faults/:id/stats", faultHandler.GetFaultStats)
		v1.GET("/faults/:id/comments", faultHandler.GetFaultComments)
		v1.POST("/faults/:id/comments", faultHandler.CreateComment)
		v1.GET("/faults/:id/history", faultHandler.GetFaultHistory)
		
		// Users
		v1.GET("/users", faultHandler.GetUsers)
	}
}
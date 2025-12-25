package main

import (
	"context"
	"fmt"
	"log"
	"log-ingestion-service/internal/api"
	"log-ingestion-service/internal/auth"
	"log-ingestion-service/internal/batch"
	"log-ingestion-service/internal/storage"
	"log-ingestion-service/pkg/config"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
)

func main() {
	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}
	
	// Initialize database connection
	ctx := context.Background()
	dbPool, err := storage.NewConnection(ctx, &cfg.Database)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer dbPool.Close()
	
	// Initialize repository
	repo := storage.NewRepository(dbPool)
	
	// Initialize key manager
	keyManager := auth.NewKeyManager(repo)
	
	// Initialize batcher
	batcher := batch.NewBatcher(repo, &cfg.Batch)
	defer batcher.Shutdown()
	
	// Initialize handler
	handler := api.NewHandler(batcher)
	
	// Initialize admin handler
	adminHandler := api.NewAdminHandler(repo, batcher, cfg)
	
	// Setup router
	router := gin.Default()
	
	// Serve static files from Vue build
	router.Static("/assets", "./web/dist/assets")
	
	// Serve Vue app index.html for all non-API routes (SPA routing)
	router.NoRoute(func(c *gin.Context) {
		// Don't serve index.html for API routes
		path := c.Request.URL.Path
		if len(path) >= 4 && path[:4] == "/api" {
			c.JSON(http.StatusNotFound, gin.H{"error": "Not found"})
			return
		}
		c.File("./web/dist/index.html")
	})
	
	// Add request logging middleware
	router.Use(gin.Logger())
	router.Use(gin.Recovery())
	
	// Setup routes
	api.SetupRoutes(router, handler, keyManager, cfg)
	
	// Setup admin routes
	api.SetupAdminRoutes(router, adminHandler, cfg)
	
	// Create HTTP server
	srv := &http.Server{
		Addr:         fmt.Sprintf("%s:%d", cfg.Server.Host, cfg.Server.Port),
		Handler:      router,
		ReadTimeout:  cfg.Server.ReadTimeout,
		WriteTimeout: cfg.Server.WriteTimeout,
	}
	
	// Start server in a goroutine
	go func() {
		log.Printf("Starting server on %s:%d", cfg.Server.Host, cfg.Server.Port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Failed to start server: %v", err)
		}
	}()
	
	// Wait for interrupt signal to gracefully shutdown the server
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	
	log.Println("Shutting down server...")
	
	// Graceful shutdown with timeout
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}
	
	log.Println("Server exited")
}


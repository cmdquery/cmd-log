package auth

import (
	"log-ingestion-service/pkg/config"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

// APIKeyAuth middleware validates API keys
func APIKeyAuth(cfg *config.AuthConfig) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Get API key from header
		apiKey := c.GetHeader("X-API-Key")
		if apiKey == "" {
			// Try Authorization header
			authHeader := c.GetHeader("Authorization")
			if authHeader != "" {
				parts := strings.Split(authHeader, " ")
				if len(parts) == 2 && strings.ToLower(parts[0]) == "bearer" {
					apiKey = parts[1]
				} else if len(parts) == 1 {
					apiKey = parts[0]
				}
			}
		}
		
		if apiKey == "" {
			c.JSON(http.StatusUnauthorized, gin.H{
				"error": "API key is required",
			})
			c.Abort()
			return
		}
		
		// Validate API key
		valid := false
		for _, key := range cfg.APIKeys {
			if key == apiKey {
				valid = true
				break
			}
		}
		
		if !valid {
			c.JSON(http.StatusUnauthorized, gin.H{
				"error": "Invalid API key",
			})
			c.Abort()
			return
		}
		
		// Store API key in context for potential use in rate limiting
		c.Set("api_key", apiKey)
		c.Next()
	}
}


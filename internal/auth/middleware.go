package auth

import (
	"encoding/json"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

// APIKeyAuth middleware validates API keys using KeyManager
func APIKeyAuth(keyManager *KeyManager) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Get API key from header
		apiKey := c.GetHeader("X-API-Key")
		// #region agent log
		if f, _ := os.OpenFile("/Users/moiz/Code/cmd-log/.cursor/debug.log", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644); f != nil {
			json.NewEncoder(f).Encode(map[string]interface{}{"sessionId": "debug-session", "runId": "run1", "hypothesisId": "C", "location": "middleware.go:14", "message": "Extracted X-API-Key header", "data": map[string]interface{}{"apiKey": apiKey, "path": c.Request.URL.Path, "method": c.Request.Method}, "timestamp": time.Now().UnixMilli()})
			f.Close()
		}
		// #endregion
		if apiKey == "" {
			// Try Authorization header
			authHeader := c.GetHeader("Authorization")
			// #region agent log
			if f, _ := os.OpenFile("/Users/moiz/Code/cmd-log/.cursor/debug.log", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644); f != nil {
				json.NewEncoder(f).Encode(map[string]interface{}{"sessionId": "debug-session", "runId": "run1", "hypothesisId": "C", "location": "middleware.go:17", "message": "Checking Authorization header", "data": map[string]interface{}{"authHeader": authHeader}, "timestamp": time.Now().UnixMilli()})
				f.Close()
			}
			// #endregion
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
			// #region agent log
			if f, _ := os.OpenFile("/Users/moiz/Code/cmd-log/.cursor/debug.log", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644); f != nil {
				json.NewEncoder(f).Encode(map[string]interface{}{"sessionId": "debug-session", "runId": "run1", "hypothesisId": "C", "location": "middleware.go:28", "message": "API key is empty", "data": map[string]interface{}{"path": c.Request.URL.Path}, "timestamp": time.Now().UnixMilli()})
				f.Close()
			}
			// #endregion
			c.JSON(http.StatusUnauthorized, gin.H{
				"error": "API key is required",
			})
			c.Abort()
			return
		}
		
		// Validate API key using KeyManager
		ctx := c.Request.Context()
		// #region agent log
		if f, _ := os.OpenFile("/Users/moiz/Code/cmd-log/.cursor/debug.log", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644); f != nil {
			json.NewEncoder(f).Encode(map[string]interface{}{"sessionId": "debug-session", "runId": "run1", "hypothesisId": "A,B,C,D,E", "location": "middleware.go:38", "message": "Calling ValidateKey", "data": map[string]interface{}{"apiKey": apiKey, "apiKeyLength": len(apiKey)}, "timestamp": time.Now().UnixMilli()})
			f.Close()
		}
		// #endregion
		valid := keyManager.ValidateKey(ctx, apiKey)
		// #region agent log
		if f, _ := os.OpenFile("/Users/moiz/Code/cmd-log/.cursor/debug.log", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644); f != nil {
			json.NewEncoder(f).Encode(map[string]interface{}{"sessionId": "debug-session", "runId": "run1", "hypothesisId": "A,B,C,D,E", "location": "middleware.go:40", "message": "ValidateKey returned", "data": map[string]interface{}{"valid": valid, "apiKey": apiKey}, "timestamp": time.Now().UnixMilli()})
			f.Close()
		}
		// #endregion
		
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


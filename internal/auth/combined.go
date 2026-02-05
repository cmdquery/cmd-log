package auth

import (
	"fmt"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

// CombinedAuth middleware accepts either a valid API key OR a valid JWT token.
// This allows the frontend (JWT) and external services (API key) to both access /api/v1/* routes.
func CombinedAuth(keyManager *KeyManager, jwtSecret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Extract token/key from headers
		apiKey := c.GetHeader("X-API-Key")
		authHeader := c.GetHeader("Authorization")
		bearerToken := ""

		if authHeader != "" {
			parts := strings.SplitN(authHeader, " ", 2)
			if len(parts) == 2 && strings.ToLower(parts[0]) == "bearer" {
				bearerToken = parts[1]
			} else if len(parts) == 1 {
				apiKey = parts[0]
			}
		}

		// Also try auth_token cookie (for frontend)
		cookieToken := ""
		if cookie, err := c.Cookie("auth_token"); err == nil && cookie != "" {
			cookieToken = cookie
		}

		// Strategy 1: Try API key auth first (X-API-Key header)
		if apiKey != "" {
			ctx := c.Request.Context()
			if keyManager.ValidateKey(ctx, apiKey) {
				c.Set("api_key", apiKey)
				c.Next()
				return
			}
		}

		// Strategy 2: Try JWT from Bearer token or cookie
		tokenString := bearerToken
		if tokenString == "" {
			tokenString = cookieToken
		}

		if tokenString != "" {
			claims := &JWTClaims{}
			token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
				if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
					return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
				}
				return []byte(jwtSecret), nil
			})

			if err == nil && token.Valid {
				c.Set("user_id", claims.UserID)
				c.Set("user_email", claims.UserEmail)
				c.Set("user_name", claims.UserName)
				c.Next()
				return
			}
		}

		// Neither auth method succeeded
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "Valid API key or authentication token required",
		})
		c.Abort()
	}
}

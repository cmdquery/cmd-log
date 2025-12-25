package middleware

import (
	"log-ingestion-service/pkg/config"
	"net/http"
	"sync"

	"github.com/gin-gonic/gin"
	"golang.org/x/time/rate"
)

// RateLimiter manages rate limiting per API key
type RateLimiter struct {
	limiters map[string]*rate.Limiter
	mu       sync.RWMutex
	config   *config.RateLimitConfig
}

// NewRateLimiter creates a new rate limiter
func NewRateLimiter(cfg *config.RateLimitConfig) *RateLimiter {
	return &RateLimiter{
		limiters: make(map[string]*rate.Limiter),
		config:   cfg,
	}
}

// getLimiter returns or creates a limiter for the given API key
func (rl *RateLimiter) getLimiter(apiKey string) *rate.Limiter {
	rl.mu.RLock()
	limiter, exists := rl.limiters[apiKey]
	rl.mu.RUnlock()
	
	if exists {
		return limiter
	}
	
	rl.mu.Lock()
	defer rl.mu.Unlock()
	
	// Double check
	if limiter, exists := rl.limiters[apiKey]; exists {
		return limiter
	}
	
	// Create new limiter
	rps := float64(rl.config.DefaultRPS)
	burst := rl.config.Burst
	limiter = rate.NewLimiter(rate.Limit(rps), burst)
	rl.limiters[apiKey] = limiter
	
	return limiter
}

// RateLimit middleware enforces rate limiting
func RateLimit(cfg *config.RateLimitConfig) gin.HandlerFunc {
	if !cfg.Enabled {
		return func(c *gin.Context) {
			c.Next()
		}
	}
	
	limiter := NewRateLimiter(cfg)
	
	return func(c *gin.Context) {
		apiKey, exists := c.Get("api_key")
		if !exists {
			apiKey = "anonymous"
		}
		
		apiKeyStr, ok := apiKey.(string)
		if !ok {
			apiKeyStr = "anonymous"
		}
		
		l := limiter.getLimiter(apiKeyStr)
		
		if !l.Allow() {
			c.JSON(http.StatusTooManyRequests, gin.H{
				"error": "Rate limit exceeded",
			})
			c.Abort()
			return
		}
		
		c.Next()
	}
}


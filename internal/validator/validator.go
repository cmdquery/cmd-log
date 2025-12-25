package validator

import (
	"fmt"
	"log-ingestion-service/pkg/models"
	"regexp"
	"strings"
	"time"
)

// Validator validates log entries
type Validator struct {
	maxMessageLength int
	maxServiceLength int
	allowedLevels    map[string]bool
}

// NewValidator creates a new validator
func NewValidator() *Validator {
	return &Validator{
		maxMessageLength: 10000, // 10KB max message length
		maxServiceLength: 255,
		allowedLevels: map[string]bool{
			"DEBUG":    true,
			"INFO":     true,
			"WARN":     true,
			"WARNING":  true,
			"ERROR":    true,
			"FATAL":    true,
			"CRITICAL": true,
		},
	}
}

// Validate validates a log entry
func (v *Validator) Validate(logEntry *models.LogEntry) error {
	// Validate timestamp
	if logEntry.Timestamp.IsZero() {
		return fmt.Errorf("timestamp is required")
	}
	
	// Validate timestamp is not too far in the future (allow 1 hour buffer)
	maxFutureTime := time.Now().Add(1 * time.Hour)
	if logEntry.Timestamp.After(maxFutureTime) {
		return fmt.Errorf("timestamp cannot be more than 1 hour in the future")
	}
	
	// Validate timestamp is not too far in the past (allow 7 days)
	maxPastTime := time.Now().Add(-7 * 24 * time.Hour)
	if logEntry.Timestamp.Before(maxPastTime) {
		return fmt.Errorf("timestamp cannot be more than 7 days in the past")
	}
	
	// Validate service
	if logEntry.Service == "" {
		return fmt.Errorf("service is required")
	}
	if len(logEntry.Service) > v.maxServiceLength {
		return fmt.Errorf("service name exceeds maximum length of %d", v.maxServiceLength)
	}
	
	// Validate level
	upperLevel := strings.ToUpper(logEntry.Level)
	if !v.allowedLevels[upperLevel] {
		return fmt.Errorf("invalid log level: %s", logEntry.Level)
	}
	logEntry.Level = upperLevel // Normalize to uppercase
	
	// Validate message
	if logEntry.Message == "" {
		return fmt.Errorf("message is required")
	}
	if len(logEntry.Message) > v.maxMessageLength {
		return fmt.Errorf("message exceeds maximum length of %d", v.maxMessageLength)
	}
	
	return nil
}

// Sanitize sanitizes a log entry by removing sensitive data
func (v *Validator) Sanitize(logEntry *models.LogEntry) {
	// Sanitize service name (remove special characters, keep alphanumeric, dash, underscore)
	re := regexp.MustCompile(`[^a-zA-Z0-9\-_]`)
	logEntry.Service = re.ReplaceAllString(logEntry.Service, "")
	
	// Sanitize level (already validated, just ensure uppercase)
	logEntry.Level = strings.ToUpper(logEntry.Level)
	
	// Sanitize message (remove null bytes and control characters except newlines and tabs)
	re = regexp.MustCompile(`[\x00-\x08\x0B-\x0C\x0E-\x1F]`)
	logEntry.Message = re.ReplaceAllString(logEntry.Message, "")
	
	// Sanitize metadata - remove sensitive fields
	if logEntry.Metadata != nil {
		sensitiveFields := []string{"password", "token", "secret", "api_key", "apikey", "auth", "authorization", "credit_card", "ssn", "social_security"}
		for _, field := range sensitiveFields {
			delete(logEntry.Metadata, field)
			delete(logEntry.Metadata, strings.ToLower(field))
			delete(logEntry.Metadata, strings.ToUpper(field))
		}
	}
}


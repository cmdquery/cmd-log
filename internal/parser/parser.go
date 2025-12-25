package parser

import (
	"encoding/json"
	"fmt"
	"log-ingestion-service/pkg/models"
	"strings"
	"time"
)

// Parser interface for parsing logs
type Parser interface {
	Parse(data []byte) (*models.LogEntry, error)
}

// JSONParser parses JSON formatted logs
type JSONParser struct{}

// NewJSONParser creates a new JSON parser
func NewJSONParser() *JSONParser {
	return &JSONParser{}
}

// Parse parses JSON log data
func (p *JSONParser) Parse(data []byte) (*models.LogEntry, error) {
	var logEntry models.LogEntry
	
	if err := json.Unmarshal(data, &logEntry); err != nil {
		return nil, fmt.Errorf("failed to parse JSON log: %w", err)
	}
	
	// Set default timestamp if not provided
	if logEntry.Timestamp.IsZero() {
		logEntry.Timestamp = time.Now()
	}
	
	// Validate required fields
	if logEntry.Service == "" {
		return nil, fmt.Errorf("service field is required")
	}
	if logEntry.Level == "" {
		return nil, fmt.Errorf("level field is required")
	}
	if logEntry.Message == "" {
		return nil, fmt.Errorf("message field is required")
	}
	
	return &logEntry, nil
}

// TextParser parses plain text formatted logs
type TextParser struct{}

// NewTextParser creates a new text parser
func NewTextParser() *TextParser {
	return &TextParser{}
}

// Parse parses plain text log data
// Expected format: [TIMESTAMP] LEVEL SERVICE: MESSAGE
// Or simpler: LEVEL SERVICE: MESSAGE (timestamp will be set to now)
func (p *TextParser) Parse(data []byte) (*models.LogEntry, error) {
	text := strings.TrimSpace(string(data))
	if text == "" {
		return nil, fmt.Errorf("empty log entry")
	}
	
	logEntry := models.LogEntry{
		Timestamp: time.Now(),
		Metadata:  make(map[string]interface{}),
	}
	
	// Try to parse common log formats
	// Format 1: [2024-01-01T12:00:00Z] INFO service-name: message
	// Format 2: INFO service-name: message
	// Format 3: service-name [INFO]: message
	
	parts := strings.Fields(text)
	if len(parts) < 3 {
		// Simple format: just use the whole text as message
		logEntry.Message = text
		logEntry.Level = "INFO"
		logEntry.Service = "unknown"
		return &logEntry, nil
	}
	
	// Try to detect timestamp in brackets
	if strings.HasPrefix(parts[0], "[") {
		// Extract timestamp
		timestampStr := strings.Trim(parts[0], "[]")
		if t, err := time.Parse(time.RFC3339, timestampStr); err == nil {
			logEntry.Timestamp = t
			parts = parts[1:]
		} else if t, err := time.Parse("2006-01-02T15:04:05Z", timestampStr); err == nil {
			logEntry.Timestamp = t
			parts = parts[1:]
		}
	}
	
	// Try to find level (common log levels)
	levelFound := false
	levelIndex := -1
	levels := []string{"DEBUG", "INFO", "WARN", "WARNING", "ERROR", "FATAL", "CRITICAL"}
	
	for i, part := range parts {
		upperPart := strings.ToUpper(part)
		for _, level := range levels {
			if upperPart == level {
				logEntry.Level = level
				levelIndex = i
				levelFound = true
				break
			}
		}
		if levelFound {
			break
		}
	}
	
	if !levelFound {
		logEntry.Level = "INFO"
	}
	
	// Find service name (usually after level or at the beginning)
	serviceIndex := -1
	if levelIndex >= 0 && levelIndex+1 < len(parts) {
		serviceIndex = levelIndex + 1
	} else if levelIndex < 0 && len(parts) > 0 {
		serviceIndex = 0
	}
	
	if serviceIndex >= 0 && serviceIndex < len(parts) {
		servicePart := parts[serviceIndex]
		// Remove colon if present
		servicePart = strings.TrimSuffix(servicePart, ":")
		logEntry.Service = servicePart
	} else {
		logEntry.Service = "unknown"
	}
	
	// Rest is the message
	messageStart := serviceIndex + 1
	if levelIndex >= 0 {
		messageStart = levelIndex + 2
	}
	if messageStart < len(parts) {
		logEntry.Message = strings.Join(parts[messageStart:], " ")
	} else {
		logEntry.Message = text
	}
	
	return &logEntry, nil
}

// AutoParser automatically detects and parses log format
type AutoParser struct {
	jsonParser *JSONParser
	textParser *TextParser
}

// NewAutoParser creates a new auto-detecting parser
func NewAutoParser() *AutoParser {
	return &AutoParser{
		jsonParser: NewJSONParser(),
		textParser: NewTextParser(),
	}
}

// Parse automatically detects format and parses the log
func (p *AutoParser) Parse(data []byte) (*models.LogEntry, error) {
	// Try JSON first
	trimmed := strings.TrimSpace(string(data))
	if strings.HasPrefix(trimmed, "{") || strings.HasPrefix(trimmed, "[") {
		return p.jsonParser.Parse(data)
	}
	
	// Fall back to text parser
	return p.textParser.Parse(data)
}


package models

import "time"

// LogEntry represents a single log entry
type LogEntry struct {
	Timestamp time.Time              `json:"timestamp"`
	Service   string                 `json:"service"`
	Level     string                 `json:"level"`
	Message   string                 `json:"message"`
	Metadata  map[string]interface{} `json:"metadata,omitempty"`
}

// LogBatch represents a batch of log entries
type LogBatch struct {
	Logs []LogEntry `json:"logs"`
}

// LogRequest represents a single log ingestion request
type LogRequest struct {
	Log LogEntry `json:"log"`
}

// BatchLogRequest represents a batch log ingestion request
type BatchLogRequest struct {
	Logs []LogEntry `json:"logs"`
}


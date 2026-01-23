package parser

import (
	"fmt"
	"log-ingestion-service/internal/storage"
	"strconv"
	"strings"
	"time"
)

// SearchParser parses tokenized search queries
type SearchParser struct{}

// NewSearchParser creates a new search parser
func NewSearchParser() *SearchParser {
	return &SearchParser{}
}

// ParseQuery parses a search query string into FaultFilters
func (p *SearchParser) ParseQuery(query string) (*storage.FaultFilters, error) {
	filters := &storage.FaultFilters{
		Limit:  50, // Default
		Offset: 0,
	}
	
	if query == "" {
		return filters, nil
	}
	
	// Split query into tokens
	tokens := p.tokenize(query)
	
	// Parse each token
	for _, token := range tokens {
		if err := p.parseToken(token, filters); err != nil {
			return nil, fmt.Errorf("error parsing token '%s': %w", token, err)
		}
	}
	
	return filters, nil
}

// tokenize splits a query string into tokens
func (p *SearchParser) tokenize(query string) []string {
	// Split by spaces, but preserve quoted strings
	var tokens []string
	var current strings.Builder
	inQuotes := false
	
	for i, char := range query {
		if char == '"' {
			if inQuotes {
				// End of quoted string
				if current.Len() > 0 {
					tokens = append(tokens, current.String())
					current.Reset()
				}
				inQuotes = false
			} else {
				// Start of quoted string
				if current.Len() > 0 {
					tokens = append(tokens, current.String())
					current.Reset()
				}
				inQuotes = true
			}
		} else if char == ' ' && !inQuotes {
			// Space outside quotes - end of token
			if current.Len() > 0 {
				tokens = append(tokens, current.String())
				current.Reset()
			}
		} else {
			current.WriteRune(char)
		}
		
		// Handle last token
		if i == len(query)-1 && current.Len() > 0 {
			tokens = append(tokens, current.String())
		}
	}
	
	return tokens
}

// parseToken parses a single token and updates filters
func (p *SearchParser) parseToken(token string, filters *storage.FaultFilters) error {
	if token == "" {
		return nil
	}
	
	// Handle negated tokens (starting with -)
	negated := false
	if strings.HasPrefix(token, "-") {
		negated = true
		token = token[1:]
	}
	
	// Check for key:value format
	if strings.Contains(token, ":") {
		parts := strings.SplitN(token, ":", 2)
		if len(parts) != 2 {
			return fmt.Errorf("invalid token format: %s", token)
		}
		
		key := strings.ToLower(parts[0])
		value := parts[1]
		
		// Remove quotes if present
		value = strings.Trim(value, "\"")
		
		switch key {
		case "is":
			return p.parseIsToken(value, negated, filters)
		case "environment", "env":
			return p.parseEnvironmentToken(value, filters)
		case "assignee":
			return p.parseAssigneeToken(value, filters)
		case "tag", "tags":
			return p.parseTagToken(value, filters)
		case "occurred.after", "after":
			return p.parseDateToken(value, filters, true)
		case "occurred.before", "before":
			return p.parseDateToken(value, filters, false)
		default:
			// Unknown key, treat as search text
			if filters.Search == "" {
				filters.Search = token
			} else {
				filters.Search += " " + token
			}
		}
	} else {
		// Plain text search
		if filters.Search == "" {
			filters.Search = token
		} else {
			filters.Search += " " + token
		}
	}
	
	return nil
}

// parseIsToken parses is:resolved, is:ignored tokens
func (p *SearchParser) parseIsToken(value string, negated bool, filters *storage.FaultFilters) error {
	value = strings.ToLower(value)
	
	switch value {
	case "resolved":
		resolved := !negated
		filters.Resolved = &resolved
	case "ignored":
		ignored := !negated
		filters.Ignored = &ignored
	default:
		return fmt.Errorf("unknown 'is' value: %s", value)
	}
	
	return nil
}

// parseEnvironmentToken parses environment:production tokens
func (p *SearchParser) parseEnvironmentToken(value string, filters *storage.FaultFilters) error {
	filters.Environment = &value
	return nil
}

// parseAssigneeToken parses assignee:email or assignee:me tokens
func (p *SearchParser) parseAssigneeToken(value string, filters *storage.FaultFilters) error {
	// For now, we'll need user ID lookup
	// This will be handled in the handler layer
	// Store as string for now
	if value == "me" {
		// Will be resolved to user ID in handler
		filters.AssigneeID = nil // Special marker for "me"
	} else {
		// Try to parse as integer (user ID)
		if id, err := strconv.ParseInt(value, 10, 64); err == nil {
			filters.AssigneeID = &id
		} else {
			// Email or name - will need lookup
			// For now, store in search
			if filters.Search == "" {
				filters.Search = value
			} else {
				filters.Search += " " + value
			}
		}
	}
	
	return nil
}

// parseTagToken parses tag:value tokens
func (p *SearchParser) parseTagToken(value string, filters *storage.FaultFilters) error {
	if filters.Tags == nil {
		filters.Tags = []string{}
	}
	filters.Tags = append(filters.Tags, value)
	return nil
}

// parseDateToken parses date tokens
func (p *SearchParser) parseDateToken(value string, filters *storage.FaultFilters, isAfter bool) error {
	// Parse relative dates (1h, 2d, 1w) or absolute dates
	// For now, just store as string - will be parsed in handler
	// This is a placeholder for future date parsing
	return nil
}

// ParseLimitOffset parses limit and offset from query parameters
func (p *SearchParser) ParseLimitOffset(limitStr, offsetStr string) (int, int, error) {
	limit := 50
	offset := 0
	
	if limitStr != "" {
		parsed, err := strconv.Atoi(limitStr)
		if err != nil {
			return 0, 0, fmt.Errorf("invalid limit: %w", err)
		}
		if parsed > 0 && parsed <= 1000 {
			limit = parsed
		}
	}
	
	if offsetStr != "" {
		parsed, err := strconv.Atoi(offsetStr)
		if err != nil {
			return 0, 0, fmt.Errorf("invalid offset: %w", err)
		}
		if parsed >= 0 {
			offset = parsed
		}
	}
	
	return limit, offset, nil
}

// Helper function to parse relative time strings
func ParseRelativeTime(s string) (time.Time, error) {
	s = strings.ToLower(strings.TrimSpace(s))
	
	now := time.Now()
	
	// Parse formats like "1h", "2d", "1w", "30m"
	if strings.HasSuffix(s, "h") {
		hours, err := strconv.Atoi(strings.TrimSuffix(s, "h"))
		if err != nil {
			return time.Time{}, err
		}
		return now.Add(-time.Duration(hours) * time.Hour), nil
	}
	
	if strings.HasSuffix(s, "d") {
		days, err := strconv.Atoi(strings.TrimSuffix(s, "d"))
		if err != nil {
			return time.Time{}, err
		}
		return now.Add(-time.Duration(days) * 24 * time.Hour), nil
	}
	
	if strings.HasSuffix(s, "w") {
		weeks, err := strconv.Atoi(strings.TrimSuffix(s, "w"))
		if err != nil {
			return time.Time{}, err
		}
		return now.Add(-time.Duration(weeks) * 7 * 24 * time.Hour), nil
	}
	
	if strings.HasSuffix(s, "m") {
		minutes, err := strconv.Atoi(strings.TrimSuffix(s, "m"))
		if err != nil {
			return time.Time{}, err
		}
		return now.Add(-time.Duration(minutes) * time.Minute), nil
	}
	
	// Try to parse as RFC3339
	if t, err := time.Parse(time.RFC3339, s); err == nil {
		return t, nil
	}
	
	// Try common date formats
	formats := []string{
		"2006-01-02",
		"2006-01-02 15:04:05",
		"2006-01-02T15:04:05",
	}
	
	for _, format := range formats {
		if t, err := time.Parse(format, s); err == nil {
			return t, nil
		}
	}
	
	return time.Time{}, fmt.Errorf("unable to parse time: %s", s)
}

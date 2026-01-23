package fault

import (
	"context"
	"fmt"
	"log-ingestion-service/internal/storage"
	"log-ingestion-service/pkg/models"
	"time"
)

// Grouper handles fault grouping logic
type Grouper struct {
	repo *storage.Repository
}

// NewGrouper creates a new grouper
func NewGrouper(repo *storage.Repository) *Grouper {
	return &Grouper{repo: repo}
}

// ProcessNotice processes a notice and creates or updates the corresponding fault
func (g *Grouper) ProcessNotice(ctx context.Context, noticeReq *models.NoticeRequest) (*models.Fault, *models.Notice, error) {
	// Extract error information
	errorClass := noticeReq.Error.Class
	if errorClass == "" {
		errorClass = "UnknownError"
	}
	
	message := noticeReq.Error.Message
	if message == "" {
		message = "No error message"
	}
	
	// Extract location from backtrace or request
	location := g.extractLocation(noticeReq)
	
	// Extract environment
	environment := noticeReq.Server.EnvironmentName
	if environment == "" {
		environment = "production" // Default
	}
	
	// Create fault fingerprint
	fault := &models.Fault{
		ProjectID:   nil, // Single project for now
		ErrorClass:  errorClass,
		Message:     message,
		Location:     &location,
		Environment:  environment,
		Resolved:    false,
		Ignored:     false,
		Tags:        []string{},
		Public:      false,
		FirstSeenAt: time.Now(),
		LastSeenAt:  time.Now(),
	}
	
	// Find or create fault
	existingFault, err := g.repo.FindFaultByFingerprint(ctx, fault)
	if err != nil {
		// Fault doesn't exist, create it
		createdFault, err := g.repo.CreateFault(ctx, fault)
		if err != nil {
			return nil, nil, fmt.Errorf("error creating fault: %w", err)
		}
		fault = createdFault
	} else {
		fault = existingFault
		// Update last_seen_at
		fault.LastSeenAt = time.Now()
	}
	
	// Increment occurrence count
	if err := g.repo.IncrementFaultOccurrence(ctx, fault.ID); err != nil {
		return nil, nil, fmt.Errorf("error incrementing occurrence: %w", err)
	}
	
	// Create notice
	notice := g.buildNotice(noticeReq, fault.ID)
	
	// Save notice
	if err := g.repo.CreateNotice(ctx, notice); err != nil {
		return nil, nil, fmt.Errorf("error creating notice: %w", err)
	}
	
	// Update fault occurrence count from database
	updatedFault, err := g.repo.GetFault(ctx, fault.ID)
	if err != nil {
		return nil, nil, fmt.Errorf("error getting updated fault: %w", err)
	}
	
	return updatedFault, notice, nil
}

// extractLocation extracts the location from a notice request
func (g *Grouper) extractLocation(req *models.NoticeRequest) string {
	// Try to get location from request component/action
	if req.Request.Component != "" && req.Request.Action != "" {
		return fmt.Sprintf("%s#%s", req.Request.Component, req.Request.Action)
	}
	
	// Try to get from backtrace
	if len(req.Error.Backtrace) > 0 {
		frame := req.Error.Backtrace[0]
		if frame.File != "" {
			location := frame.File
			if frame.Line != nil {
				location = fmt.Sprintf("%s:%d", location, *frame.Line)
			}
			return location
		}
	}
	
	return "unknown"
}

// buildNotice builds a Notice from a NoticeRequest
func (g *Grouper) buildNotice(req *models.NoticeRequest, faultID int64) *models.Notice {
	// Generate ULID for notice ID
	noticeID := generateULID()
	
	notice := &models.Notice{
		ID:          noticeID,
		FaultID:     faultID,
		ProjectID:   nil,
		Message:     req.Error.Message,
		Backtrace:   req.Error.Backtrace,
		Context:     req.Request.Context,
		Params:      req.Request.Params,
		Session:     req.Request.Session,
		Cookies:     req.Request.Cookies,
		Environment: req.Server.Data,
		Breadcrumbs: req.Breadcrumbs.Trail,
		CreatedAt:   time.Now(),
	}
	
	// Add environment name to environment data
	if notice.Environment == nil {
		notice.Environment = make(map[string]interface{})
	}
	if req.Server.EnvironmentName != "" {
		notice.Environment["environment_name"] = req.Server.EnvironmentName
	}
	if req.Server.Hostname != "" {
		notice.Hostname = &req.Server.Hostname
	}
	if req.Server.Revision != "" {
		notice.Revision = &req.Server.Revision
	}
	
	return notice
}

// generateULID generates a ULID string
// For now, using a simple implementation. In production, use github.com/oklog/ulid/v2
func generateULID() string {
	// Simple ULID-like ID generation
	// Format: timestamp (10 chars) + random (16 chars) = 26 chars
	// For now, using timestamp + random bytes
	timestamp := time.Now().UnixMilli()
	random := time.Now().UnixNano() % 10000000000000000
	return fmt.Sprintf("%010x%016x", timestamp, random)
}

// Fingerprint generates a fingerprint for a fault for grouping
func Fingerprint(fault *models.Fault) string {
	location := ""
	if fault.Location != nil {
		location = *fault.Location
	}
	return fmt.Sprintf("%s:%s:%s", fault.ErrorClass, location, fault.Environment)
}

// MergeFaults merges two faults (for manual merging)
func (g *Grouper) MergeFaults(ctx context.Context, sourceFaultID, targetFaultID int64) error {
	return g.repo.MergeFaults(ctx, sourceFaultID, targetFaultID)
}

package api

import (
	"context"
	"log-ingestion-service/internal/fault"
	"log-ingestion-service/internal/parser"
	"log-ingestion-service/internal/storage"
	"log-ingestion-service/pkg/models"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

// FaultHandler handles fault-related API requests
type FaultHandler struct {
	repo         *storage.Repository
	grouper      *fault.Grouper
	searchParser *parser.SearchParser
}

// NewFaultHandler creates a new fault handler
func NewFaultHandler(repo *storage.Repository) *FaultHandler {
	return &FaultHandler{
		repo:         repo,
		grouper:      fault.NewGrouper(repo),
		searchParser: parser.NewSearchParser(),
	}
}

// IngestNotice handles Honeybadger-compatible notice ingestion
func (h *FaultHandler) IngestNotice(c *gin.Context) {
	var req models.NoticeRequest
	
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request body",
			"details": err.Error(),
		})
		return
	}
	
	ctx := context.Background()
	
	// Process notice and create/update fault
	fault, notice, err := h.grouper.ProcessNotice(ctx, &req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to process notice",
			"details": err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusCreated, gin.H{
		"id": notice.ID,
		"fault_id": fault.ID,
	})
}

// ListFaults handles GET /api/v1/faults
func (h *FaultHandler) ListFaults(c *gin.Context) {
	ctx := context.Background()
	
	// Parse search query
	query := c.Query("q")
	filters, err := h.searchParser.ParseQuery(query)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid search query",
			"details": err.Error(),
		})
		return
	}
	
	// Parse limit and offset
	limit, offset, err := h.searchParser.ParseLimitOffset(
		c.Query("limit"),
		c.Query("offset"),
	)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid pagination parameters",
			"details": err.Error(),
		})
		return
	}
	
	filters.Limit = limit
	filters.Offset = offset
	
	// Get faults
	faults, total, err := h.repo.ListFaults(ctx, *filters)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to list faults",
			"details": err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{
		"faults": faults,
		"total": total,
		"limit": limit,
		"offset": offset,
	})
}

// GetFault handles GET /api/v1/faults/:id
func (h *FaultHandler) GetFault(c *gin.Context) {
	ctx := context.Background()
	
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid fault ID",
		})
		return
	}
	
	fault, err := h.repo.GetFault(ctx, id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Fault not found",
			"details": err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusOK, fault)
}

// UpdateFault handles PATCH /api/v1/faults/:id
func (h *FaultHandler) UpdateFault(c *gin.Context) {
	ctx := context.Background()
	
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid fault ID",
		})
		return
	}
	
	var updates map[string]interface{}
	if err := c.ShouldBindJSON(&updates); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request body",
			"details": err.Error(),
		})
		return
	}
	
	if err := h.repo.UpdateFault(ctx, id, updates); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to update fault",
			"details": err.Error(),
		})
		return
	}
	
	// Return updated fault
	fault, err := h.repo.GetFault(ctx, id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to get updated fault",
			"details": err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusOK, fault)
}

// ResolveFault handles POST /api/v1/faults/:id/resolve
func (h *FaultHandler) ResolveFault(c *gin.Context) {
	ctx := context.Background()
	
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid fault ID",
		})
		return
	}
	
	var userID *int64
	// TODO: Get user ID from auth context
	// For now, nil
	
	if err := h.repo.ResolveFault(ctx, id, userID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to resolve fault",
			"details": err.Error(),
		})
		return
	}
	
	fault, err := h.repo.GetFault(ctx, id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to get fault",
			"details": err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusOK, fault)
}

// UnresolveFault handles POST /api/v1/faults/:id/unresolve
func (h *FaultHandler) UnresolveFault(c *gin.Context) {
	ctx := context.Background()
	
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid fault ID",
		})
		return
	}
	
	var userID *int64
	// TODO: Get user ID from auth context
	
	if err := h.repo.UnresolveFault(ctx, id, userID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to unresolve fault",
			"details": err.Error(),
		})
		return
	}
	
	fault, err := h.repo.GetFault(ctx, id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to get fault",
			"details": err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusOK, fault)
}

// IgnoreFault handles POST /api/v1/faults/:id/ignore
func (h *FaultHandler) IgnoreFault(c *gin.Context) {
	ctx := context.Background()
	
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid fault ID",
		})
		return
	}
	
	var userID *int64
	
	if err := h.repo.IgnoreFault(ctx, id, userID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to ignore fault",
			"details": err.Error(),
		})
		return
	}
	
	fault, err := h.repo.GetFault(ctx, id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to get fault",
			"details": err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusOK, fault)
}

// AssignFault handles POST /api/v1/faults/:id/assign
func (h *FaultHandler) AssignFault(c *gin.Context) {
	ctx := context.Background()
	
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid fault ID",
		})
		return
	}
	
	var req struct {
		UserID *int64 `json:"user_id"`
	}
	
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request body",
			"details": err.Error(),
		})
		return
	}
	
	if err := h.repo.AssignFault(ctx, id, req.UserID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to assign fault",
			"details": err.Error(),
		})
		return
	}
	
	fault, err := h.repo.GetFault(ctx, id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to get fault",
			"details": err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusOK, fault)
}

// AddFaultTags handles POST /api/v1/faults/:id/tags
func (h *FaultHandler) AddFaultTags(c *gin.Context) {
	ctx := context.Background()
	
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid fault ID",
		})
		return
	}
	
	var req struct {
		Tags []string `json:"tags" binding:"required"`
	}
	
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request body",
			"details": err.Error(),
		})
		return
	}
	
	if err := h.repo.AddFaultTags(ctx, id, req.Tags); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to add tags",
			"details": err.Error(),
		})
		return
	}
	
	fault, err := h.repo.GetFault(ctx, id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to get fault",
			"details": err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusOK, fault)
}

// ReplaceFaultTags handles PUT /api/v1/faults/:id/tags
func (h *FaultHandler) ReplaceFaultTags(c *gin.Context) {
	ctx := context.Background()
	
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid fault ID",
		})
		return
	}
	
	var req struct {
		Tags []string `json:"tags" binding:"required"`
	}
	
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request body",
			"details": err.Error(),
		})
		return
	}
	
	if err := h.repo.ReplaceFaultTags(ctx, id, req.Tags); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to replace tags",
			"details": err.Error(),
		})
		return
	}
	
	fault, err := h.repo.GetFault(ctx, id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to get fault",
			"details": err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusOK, fault)
}

// GetFaultNotices handles GET /api/v1/faults/:id/notices
func (h *FaultHandler) GetFaultNotices(c *gin.Context) {
	ctx := context.Background()
	
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid fault ID",
		})
		return
	}
	
	limit, offset, err := h.searchParser.ParseLimitOffset(
		c.Query("limit"),
		c.Query("offset"),
	)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid pagination parameters",
			"details": err.Error(),
		})
		return
	}
	
	notices, err := h.repo.GetFaultOccurrences(ctx, id, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to get notices",
			"details": err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{
		"notices": notices,
		"limit": limit,
		"offset": offset,
	})
}

// GetFaultStats handles GET /api/v1/faults/:id/stats
func (h *FaultHandler) GetFaultStats(c *gin.Context) {
	ctx := context.Background()
	
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid fault ID",
		})
		return
	}
	
	stats, err := h.repo.GetFaultStats(ctx, id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to get stats",
			"details": err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusOK, stats)
}

// CreateComment handles POST /api/v1/faults/:id/comments
func (h *FaultHandler) CreateComment(c *gin.Context) {
	ctx := context.Background()
	
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid fault ID",
		})
		return
	}
	
	var req struct {
		Comment string `json:"comment" binding:"required"`
		UserID  int64  `json:"user_id" binding:"required"`
	}
	
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request body",
			"details": err.Error(),
		})
		return
	}
	
	comment := &models.Comment{
		FaultID: id,
		UserID:  req.UserID,
		Comment: req.Comment,
	}
	
	if err := h.repo.CreateComment(ctx, comment); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to create comment",
			"details": err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusCreated, comment)
}

// GetFaultComments handles GET /api/v1/faults/:id/comments
func (h *FaultHandler) GetFaultComments(c *gin.Context) {
	ctx := context.Background()
	
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid fault ID",
		})
		return
	}
	
	comments, err := h.repo.GetFaultComments(ctx, id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to get comments",
			"details": err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{
		"comments": comments,
	})
}

// GetFaultHistory handles GET /api/v1/faults/:id/history
func (h *FaultHandler) GetFaultHistory(c *gin.Context) {
	ctx := context.Background()
	
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid fault ID",
		})
		return
	}
	
	history, err := h.repo.GetFaultHistory(ctx, id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to get history",
			"details": err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{
		"history": history,
	})
}

// MergeFaults handles POST /api/v1/faults/:id/merge
func (h *FaultHandler) MergeFaults(c *gin.Context) {
	ctx := context.Background()
	
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid fault ID",
		})
		return
	}
	
	var req struct {
		TargetFaultID int64 `json:"target_fault_id" binding:"required"`
	}
	
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request body",
			"details": err.Error(),
		})
		return
	}
	
	if err := h.repo.MergeFaults(ctx, id, req.TargetFaultID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to merge faults",
			"details": err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{
		"message": "Faults merged successfully",
	})
}

// DeleteFault handles DELETE /api/v1/faults/:id
func (h *FaultHandler) DeleteFault(c *gin.Context) {
	ctx := context.Background()
	
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid fault ID",
		})
		return
	}
	
	if err := h.repo.DeleteFault(ctx, id); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to delete fault",
			"details": err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{
		"message": "Fault deleted successfully",
	})
}

// GetUsers handles GET /api/v1/users
func (h *FaultHandler) GetUsers(c *gin.Context) {
	ctx := context.Background()
	
	users, err := h.repo.GetUsers(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to get users",
			"details": err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{
		"users": users,
	})
}

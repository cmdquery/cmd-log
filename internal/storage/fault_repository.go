package storage

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log-ingestion-service/pkg/models"
	"strings"
	"time"
)

// FaultFilters represents filters for listing faults
type FaultFilters struct {
	Resolved    *bool
	Ignored     *bool
	Environment *string
	AssigneeID  *int64
	Tags        []string
	Search      string
	Limit       int
	Offset      int
}

// CreateFault creates a new fault or returns existing one based on grouping
func (r *Repository) CreateFault(ctx context.Context, fault *models.Fault) (*models.Fault, error) {
	// First try to find existing fault
	existing, err := r.FindFaultByFingerprint(ctx, fault)
	if err == nil {
		return existing, nil
	}
	
	// Fault doesn't exist, create it
	query := `
		INSERT INTO faults (project_id, error_class, message, location, environment, 
		                   first_seen_at, last_seen_at, tags)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		RETURNING id, project_id, error_class, message, location, environment,
		          resolved, ignored, assignee_id, tags, public, occurrence_count,
		          first_seen_at, last_seen_at, created_at, updated_at
	`
	
	var createdFault models.Fault
	err = r.pool.QueryRow(ctx, query,
		fault.ProjectID,
		fault.ErrorClass,
		fault.Message,
		fault.Location,
		fault.Environment,
		fault.FirstSeenAt,
		fault.LastSeenAt,
		fault.Tags,
	).Scan(
		&createdFault.ID,
		&createdFault.ProjectID,
		&createdFault.ErrorClass,
		&createdFault.Message,
		&createdFault.Location,
		&createdFault.Environment,
		&createdFault.Resolved,
		&createdFault.Ignored,
		&createdFault.AssigneeID,
		&createdFault.Tags,
		&createdFault.Public,
		&createdFault.OccurrenceCount,
		&createdFault.FirstSeenAt,
		&createdFault.LastSeenAt,
		&createdFault.CreatedAt,
		&createdFault.UpdatedAt,
	)
	
	if err != nil {
		return nil, fmt.Errorf("error creating fault: %w", err)
	}
	
	return &createdFault, nil
}

// FindFaultByFingerprint finds a fault by its fingerprint (error_class + location + environment)
func (r *Repository) FindFaultByFingerprint(ctx context.Context, fault *models.Fault) (*models.Fault, error) {
	query := `
		SELECT id, project_id, error_class, message, location, environment,
		       resolved, ignored, assignee_id, tags, public, occurrence_count,
		       first_seen_at, last_seen_at, created_at, updated_at
		FROM faults
		WHERE error_class = $1 AND location = $2 AND environment = $3
		LIMIT 1
	`
	
	var foundFault models.Fault
	err := r.pool.QueryRow(ctx, query,
		fault.ErrorClass,
		fault.Location,
		fault.Environment,
	).Scan(
		&foundFault.ID,
		&foundFault.ProjectID,
		&foundFault.ErrorClass,
		&foundFault.Message,
		&foundFault.Location,
		&foundFault.Environment,
		&foundFault.Resolved,
		&foundFault.Ignored,
		&foundFault.AssigneeID,
		&foundFault.Tags,
		&foundFault.Public,
		&foundFault.OccurrenceCount,
		&foundFault.FirstSeenAt,
		&foundFault.LastSeenAt,
		&foundFault.CreatedAt,
		&foundFault.UpdatedAt,
	)
	
	if err != nil {
		return nil, fmt.Errorf("error finding fault: %w", err)
	}
	
	return &foundFault, nil
}

// GetFault returns a fault by ID
func (r *Repository) GetFault(ctx context.Context, id int64) (*models.Fault, error) {
	query := `
		SELECT f.id, f.project_id, f.error_class, f.message, f.location, f.environment,
		       f.resolved, f.ignored, f.assignee_id, f.tags, f.public, f.occurrence_count,
		       f.first_seen_at, f.last_seen_at, f.created_at, f.updated_at,
		       u.id, u.email, u.name, u.avatar_url, u.created_at
		FROM faults f
		LEFT JOIN users u ON f.assignee_id = u.id
		WHERE f.id = $1
	`
	
	var fault models.Fault
	var userID sql.NullInt64
	var userEmail, userName sql.NullString
	var userAvatarURL sql.NullString
	var userCreatedAt sql.NullTime
	
	err := r.pool.QueryRow(ctx, query, id).Scan(
		&fault.ID,
		&fault.ProjectID,
		&fault.ErrorClass,
		&fault.Message,
		&fault.Location,
		&fault.Environment,
		&fault.Resolved,
		&fault.Ignored,
		&fault.AssigneeID,
		&fault.Tags,
		&fault.Public,
		&fault.OccurrenceCount,
		&fault.FirstSeenAt,
		&fault.LastSeenAt,
		&fault.CreatedAt,
		&fault.UpdatedAt,
		&userID,
		&userEmail,
		&userName,
		&userAvatarURL,
		&userCreatedAt,
	)
	
	if err != nil {
		return nil, fmt.Errorf("error getting fault: %w", err)
	}
	
	if userID.Valid {
		fault.Assignee = &models.User{
			ID:        userID.Int64,
			Email:     userEmail.String,
			Name:      userName.String,
			CreatedAt: userCreatedAt.Time,
		}
		if userAvatarURL.Valid {
			fault.Assignee.AvatarURL = &userAvatarURL.String
		}
	}
	
	return &fault, nil
}

// ListFaults returns a list of faults with filters
func (r *Repository) ListFaults(ctx context.Context, filters FaultFilters) ([]models.Fault, int64, error) {
	var conditions []string
	var args []interface{}
	argIndex := 1
	
	// Build WHERE clause
	if filters.Resolved != nil {
		conditions = append(conditions, fmt.Sprintf("f.resolved = $%d", argIndex))
		args = append(args, *filters.Resolved)
		argIndex++
	}
	
	if filters.Ignored != nil {
		conditions = append(conditions, fmt.Sprintf("f.ignored = $%d", argIndex))
		args = append(args, *filters.Ignored)
		argIndex++
	}
	
	if filters.Environment != nil && *filters.Environment != "" {
		conditions = append(conditions, fmt.Sprintf("f.environment = $%d", argIndex))
		args = append(args, *filters.Environment)
		argIndex++
	}
	
	if filters.AssigneeID != nil {
		conditions = append(conditions, fmt.Sprintf("f.assignee_id = $%d", argIndex))
		args = append(args, *filters.AssigneeID)
		argIndex++
	}
	
	if len(filters.Tags) > 0 {
		conditions = append(conditions, fmt.Sprintf("f.tags && $%d", argIndex))
		args = append(args, filters.Tags)
		argIndex++
	}
	
	if filters.Search != "" {
		searchPattern := "%" + strings.ToLower(filters.Search) + "%"
		conditions = append(conditions, fmt.Sprintf(
			"(LOWER(f.error_class) LIKE $%d OR LOWER(f.message) LIKE $%d OR LOWER(f.location) LIKE $%d)",
			argIndex, argIndex, argIndex,
		))
		args = append(args, searchPattern)
		argIndex++
	}
	
	whereClause := ""
	if len(conditions) > 0 {
		whereClause = "WHERE " + strings.Join(conditions, " AND ")
	}
	
	// Count query
	countQuery := fmt.Sprintf(`
		SELECT COUNT(*)
		FROM faults f
		%s
	`, whereClause)
	
	var total int64
	err := r.pool.QueryRow(ctx, countQuery, args...).Scan(&total)
	if err != nil {
		return nil, 0, fmt.Errorf("error counting faults: %w", err)
	}
	
	// List query
	limit := filters.Limit
	if limit <= 0 {
		limit = 50
	}
	if limit > 1000 {
		limit = 1000
	}
	
	offset := filters.Offset
	if offset < 0 {
		offset = 0
	}
	
	listQuery := fmt.Sprintf(`
		SELECT f.id, f.project_id, f.error_class, f.message, f.location, f.environment,
		       f.resolved, f.ignored, f.assignee_id, f.tags, f.public, f.occurrence_count,
		       f.first_seen_at, f.last_seen_at, f.created_at, f.updated_at,
		       u.id, u.email, u.name, u.avatar_url, u.created_at
		FROM faults f
		LEFT JOIN users u ON f.assignee_id = u.id
		%s
		ORDER BY f.last_seen_at DESC
		LIMIT $%d OFFSET $%d
	`, whereClause, argIndex, argIndex+1)
	
	args = append(args, limit, offset)
	
	rows, err := r.pool.Query(ctx, listQuery, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("error listing faults: %w", err)
	}
	defer rows.Close()
	
	var faults []models.Fault
	for rows.Next() {
		var fault models.Fault
		var userID sql.NullInt64
		var userEmail, userName sql.NullString
		var userAvatarURL sql.NullString
		var userCreatedAt sql.NullTime
		
		err := rows.Scan(
			&fault.ID,
			&fault.ProjectID,
			&fault.ErrorClass,
			&fault.Message,
			&fault.Location,
			&fault.Environment,
			&fault.Resolved,
			&fault.Ignored,
			&fault.AssigneeID,
			&fault.Tags,
			&fault.Public,
			&fault.OccurrenceCount,
			&fault.FirstSeenAt,
			&fault.LastSeenAt,
			&fault.CreatedAt,
			&fault.UpdatedAt,
			&userID,
			&userEmail,
			&userName,
			&userAvatarURL,
			&userCreatedAt,
		)
		if err != nil {
			return nil, 0, fmt.Errorf("error scanning fault: %w", err)
		}
		
		if userID.Valid {
			fault.Assignee = &models.User{
				ID:        userID.Int64,
				Email:     userEmail.String,
				Name:      userName.String,
				CreatedAt: userCreatedAt.Time,
			}
			if userAvatarURL.Valid {
				fault.Assignee.AvatarURL = &userAvatarURL.String
			}
		}
		
		faults = append(faults, fault)
	}
	
	return faults, total, nil
}

// UpdateFault updates a fault
func (r *Repository) UpdateFault(ctx context.Context, id int64, updates map[string]interface{}) error {
	if len(updates) == 0 {
		return nil
	}
	
	var setParts []string
	var args []interface{}
	argIndex := 1
	
	for key, value := range updates {
		setParts = append(setParts, fmt.Sprintf("%s = $%d", key, argIndex))
		args = append(args, value)
		argIndex++
	}
	
	args = append(args, id)
	
	query := fmt.Sprintf(`
		UPDATE faults
		SET %s
		WHERE id = $%d
	`, strings.Join(setParts, ", "), argIndex)
	
	_, err := r.pool.Exec(ctx, query, args...)
	return err
}

// ResolveFault marks a fault as resolved
func (r *Repository) ResolveFault(ctx context.Context, id int64, userID *int64) error {
	query := `
		UPDATE faults
		SET resolved = TRUE, updated_at = NOW()
		WHERE id = $1
	`
	
	_, err := r.pool.Exec(ctx, query, id)
	if err != nil {
		return err
	}
	
	// Record history
	return r.AddFaultHistory(ctx, id, "resolved", userID, nil)
}

// UnresolveFault marks a fault as unresolved
func (r *Repository) UnresolveFault(ctx context.Context, id int64, userID *int64) error {
	query := `
		UPDATE faults
		SET resolved = FALSE, updated_at = NOW()
		WHERE id = $1
	`
	
	_, err := r.pool.Exec(ctx, query, id)
	if err != nil {
		return err
	}
	
	return r.AddFaultHistory(ctx, id, "unresolved", userID, nil)
}

// IgnoreFault marks a fault as ignored
func (r *Repository) IgnoreFault(ctx context.Context, id int64, userID *int64) error {
	query := `
		UPDATE faults
		SET ignored = TRUE, updated_at = NOW()
		WHERE id = $1
	`
	
	_, err := r.pool.Exec(ctx, query, id)
	if err != nil {
		return err
	}
	
	return r.AddFaultHistory(ctx, id, "ignored", userID, nil)
}

// UnignoreFault marks a fault as not ignored
func (r *Repository) UnignoreFault(ctx context.Context, id int64, userID *int64) error {
	query := `
		UPDATE faults
		SET ignored = FALSE, updated_at = NOW()
		WHERE id = $1
	`
	
	_, err := r.pool.Exec(ctx, query, id)
	if err != nil {
		return err
	}
	
	return r.AddFaultHistory(ctx, id, "unignored", userID, nil)
}

// AssignFault assigns a fault to a user
func (r *Repository) AssignFault(ctx context.Context, id int64, userID *int64) error {
	query := `
		UPDATE faults
		SET assignee_id = $1, updated_at = NOW()
		WHERE id = $2
	`
	
	_, err := r.pool.Exec(ctx, query, userID, id)
	if err != nil {
		return err
	}
	
	return r.AddFaultHistory(ctx, id, "assigned", userID, nil)
}

// AddFaultTags adds tags to a fault
func (r *Repository) AddFaultTags(ctx context.Context, id int64, tags []string) error {
	if len(tags) == 0 {
		return nil
	}
	
	query := `
		UPDATE faults
		SET tags = array_cat(tags, $1), updated_at = NOW()
		WHERE id = $2
	`
	
	_, err := r.pool.Exec(ctx, query, tags, id)
	return err
}

// ReplaceFaultTags replaces all tags on a fault
func (r *Repository) ReplaceFaultTags(ctx context.Context, id int64, tags []string) error {
	query := `
		UPDATE faults
		SET tags = $1, updated_at = NOW()
		WHERE id = $2
	`
	
	_, err := r.pool.Exec(ctx, query, tags, id)
	return err
}

// IncrementFaultOccurrence increments the occurrence count and updates last_seen_at
func (r *Repository) IncrementFaultOccurrence(ctx context.Context, id int64) error {
	query := `
		UPDATE faults
		SET occurrence_count = occurrence_count + 1,
		    last_seen_at = NOW(),
		    updated_at = NOW()
		WHERE id = $1
	`
	
	_, err := r.pool.Exec(ctx, query, id)
	return err
}

// GetFaultOccurrences returns notices for a fault
func (r *Repository) GetFaultOccurrences(ctx context.Context, faultID int64, limit, offset int) ([]models.Notice, error) {
	if limit <= 0 {
		limit = 50
	}
	if limit > 1000 {
		limit = 1000
	}
	if offset < 0 {
		offset = 0
	}
	
	query := `
		SELECT id, fault_id, project_id, message, backtrace, context, params,
		       session, cookies, environment, breadcrumbs, revision, hostname, created_at
		FROM notices
		WHERE fault_id = $1
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`
	
	rows, err := r.pool.Query(ctx, query, faultID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("error getting fault occurrences: %w", err)
	}
	defer rows.Close()
	
	var notices []models.Notice
	for rows.Next() {
		var notice models.Notice
		var backtraceJSON, contextJSON, paramsJSON, sessionJSON, cookiesJSON, environmentJSON, breadcrumbsJSON []byte
		var revision, hostname sql.NullString
		
		err := rows.Scan(
			&notice.ID,
			&notice.FaultID,
			&notice.ProjectID,
			&notice.Message,
			&backtraceJSON,
			&contextJSON,
			&paramsJSON,
			&sessionJSON,
			&cookiesJSON,
			&environmentJSON,
			&breadcrumbsJSON,
			&revision,
			&hostname,
			&notice.CreatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("error scanning notice: %w", err)
		}
		
		// Parse JSONB fields
		if len(backtraceJSON) > 0 {
			json.Unmarshal(backtraceJSON, &notice.Backtrace)
		}
		if len(contextJSON) > 0 {
			json.Unmarshal(contextJSON, &notice.Context)
		}
		if len(paramsJSON) > 0 {
			json.Unmarshal(paramsJSON, &notice.Params)
		}
		if len(sessionJSON) > 0 {
			json.Unmarshal(sessionJSON, &notice.Session)
		}
		if len(cookiesJSON) > 0 {
			json.Unmarshal(cookiesJSON, &notice.Cookies)
		}
		if len(environmentJSON) > 0 {
			json.Unmarshal(environmentJSON, &notice.Environment)
		}
		if len(breadcrumbsJSON) > 0 {
			json.Unmarshal(breadcrumbsJSON, &notice.Breadcrumbs)
		}
		if revision.Valid {
			notice.Revision = &revision.String
		}
		if hostname.Valid {
			notice.Hostname = &hostname.String
		}
		
		notices = append(notices, notice)
	}
	
	return notices, nil
}

// GetFaultStats returns statistics for a fault
type FaultStats struct {
	TotalOccurrences int64     `json:"total_occurrences"`
	FirstOccurred    time.Time `json:"first_occurred"`
	LastOccurred     time.Time `json:"last_occurred"`
	OneHourCount     int64     `json:"one_hour_count"`
	OneDayCount      int64     `json:"one_day_count"`
}

func (r *Repository) GetFaultStats(ctx context.Context, faultID int64) (*FaultStats, error) {
	query := `
		SELECT 
			COUNT(*) as total_occurrences,
			MIN(created_at) as first_occurred,
			MAX(created_at) as last_occurred,
			COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '1 hour') as one_hour_count,
			COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '1 day') as one_day_count
		FROM notices
		WHERE fault_id = $1
	`
	
	var stats FaultStats
	err := r.pool.QueryRow(ctx, query, faultID).Scan(
		&stats.TotalOccurrences,
		&stats.FirstOccurred,
		&stats.LastOccurred,
		&stats.OneHourCount,
		&stats.OneDayCount,
	)
	
	if err != nil {
		return nil, fmt.Errorf("error getting fault stats: %w", err)
	}
	
	return &stats, nil
}

// CreateNotice creates a new notice
func (r *Repository) CreateNotice(ctx context.Context, notice *models.Notice) error {
	query := `
		INSERT INTO notices (id, fault_id, project_id, message, backtrace, context, params,
		                    session, cookies, environment, breadcrumbs, revision, hostname, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
	`
	
	backtraceJSON, _ := json.Marshal(notice.Backtrace)
	contextJSON, _ := json.Marshal(notice.Context)
	paramsJSON, _ := json.Marshal(notice.Params)
	sessionJSON, _ := json.Marshal(notice.Session)
	cookiesJSON, _ := json.Marshal(notice.Cookies)
	environmentJSON, _ := json.Marshal(notice.Environment)
	breadcrumbsJSON, _ := json.Marshal(notice.Breadcrumbs)
	
	_, err := r.pool.Exec(ctx, query,
		notice.ID,
		notice.FaultID,
		notice.ProjectID,
		notice.Message,
		backtraceJSON,
		contextJSON,
		paramsJSON,
		sessionJSON,
		cookiesJSON,
		environmentJSON,
		breadcrumbsJSON,
		notice.Revision,
		notice.Hostname,
		notice.CreatedAt,
	)
	
	return err
}

// GetNotice returns a notice by ID
func (r *Repository) GetNotice(ctx context.Context, id string) (*models.Notice, error) {
	query := `
		SELECT id, fault_id, project_id, message, backtrace, context, params,
		       session, cookies, environment, breadcrumbs, revision, hostname, created_at
		FROM notices
		WHERE id = $1
	`
	
	var notice models.Notice
	var backtraceJSON, contextJSON, paramsJSON, sessionJSON, cookiesJSON, environmentJSON, breadcrumbsJSON []byte
	var revision, hostname sql.NullString
	
	err := r.pool.QueryRow(ctx, query, id).Scan(
		&notice.ID,
		&notice.FaultID,
		&notice.ProjectID,
		&notice.Message,
		&backtraceJSON,
		&contextJSON,
		&paramsJSON,
		&sessionJSON,
		&cookiesJSON,
		&environmentJSON,
		&breadcrumbsJSON,
		&revision,
		&hostname,
		&notice.CreatedAt,
	)
	
	if err != nil {
		return nil, fmt.Errorf("error getting notice: %w", err)
	}
	
	// Parse JSONB fields
	if len(backtraceJSON) > 0 {
		json.Unmarshal(backtraceJSON, &notice.Backtrace)
	}
	if len(contextJSON) > 0 {
		json.Unmarshal(contextJSON, &notice.Context)
	}
	if len(paramsJSON) > 0 {
		json.Unmarshal(paramsJSON, &notice.Params)
	}
	if len(sessionJSON) > 0 {
		json.Unmarshal(sessionJSON, &notice.Session)
	}
	if len(cookiesJSON) > 0 {
		json.Unmarshal(cookiesJSON, &notice.Cookies)
	}
	if len(environmentJSON) > 0 {
		json.Unmarshal(environmentJSON, &notice.Environment)
	}
	if len(breadcrumbsJSON) > 0 {
		json.Unmarshal(breadcrumbsJSON, &notice.Breadcrumbs)
	}
	if revision.Valid {
		notice.Revision = &revision.String
	}
	if hostname.Valid {
		notice.Hostname = &hostname.String
	}
	
	return &notice, nil
}

// DeleteFault deletes a fault and all associated notices
func (r *Repository) DeleteFault(ctx context.Context, id int64) error {
	query := `DELETE FROM faults WHERE id = $1`
	_, err := r.pool.Exec(ctx, query, id)
	return err
}

// AddFaultHistory adds a history entry for a fault
func (r *Repository) AddFaultHistory(ctx context.Context, faultID int64, action string, userID *int64, revision *string) error {
	query := `
		INSERT INTO fault_history (fault_id, action, user_id, revision)
		VALUES ($1, $2, $3, $4)
	`
	
	_, err := r.pool.Exec(ctx, query, faultID, action, userID, revision)
	return err
}

// GetFaultHistory returns history entries for a fault
func (r *Repository) GetFaultHistory(ctx context.Context, faultID int64) ([]models.FaultHistory, error) {
	query := `
		SELECT h.id, h.fault_id, h.action, h.user_id, h.revision, h.created_at,
		       u.id, u.email, u.name, u.avatar_url, u.created_at
		FROM fault_history h
		LEFT JOIN users u ON h.user_id = u.id
		WHERE h.fault_id = $1
		ORDER BY h.created_at DESC
	`
	
	rows, err := r.pool.Query(ctx, query, faultID)
	if err != nil {
		return nil, fmt.Errorf("error getting fault history: %w", err)
	}
	defer rows.Close()
	
	var history []models.FaultHistory
	for rows.Next() {
		var h models.FaultHistory
		var userID sql.NullInt64
		var userEmail, userName sql.NullString
		var userAvatarURL sql.NullString
		var userCreatedAt sql.NullTime
		
		err := rows.Scan(
			&h.ID,
			&h.FaultID,
			&h.Action,
			&h.UserID,
			&h.Revision,
			&h.CreatedAt,
			&userID,
			&userEmail,
			&userName,
			&userAvatarURL,
			&userCreatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("error scanning history: %w", err)
		}
		
		if userID.Valid {
			h.User = &models.User{
				ID:        userID.Int64,
				Email:     userEmail.String,
				Name:      userName.String,
				CreatedAt: userCreatedAt.Time,
			}
			if userAvatarURL.Valid {
				h.User.AvatarURL = &userAvatarURL.String
			}
		}
		
		history = append(history, h)
	}
	
	return history, nil
}

// CreateComment creates a comment on a fault
func (r *Repository) CreateComment(ctx context.Context, comment *models.Comment) error {
	query := `
		INSERT INTO fault_comments (fault_id, user_id, comment)
		VALUES ($1, $2, $3)
		RETURNING id, created_at
	`
	
	err := r.pool.QueryRow(ctx, query, comment.FaultID, comment.UserID, comment.Comment).Scan(
		&comment.ID,
		&comment.CreatedAt,
	)
	return err
}

// GetFaultComments returns comments for a fault
func (r *Repository) GetFaultComments(ctx context.Context, faultID int64) ([]models.Comment, error) {
	query := `
		SELECT c.id, c.fault_id, c.user_id, c.comment, c.created_at,
		       u.id, u.email, u.name, u.avatar_url, u.created_at
		FROM fault_comments c
		JOIN users u ON c.user_id = u.id
		WHERE c.fault_id = $1
		ORDER BY c.created_at ASC
	`
	
	rows, err := r.pool.Query(ctx, query, faultID)
	if err != nil {
		return nil, fmt.Errorf("error getting comments: %w", err)
	}
	defer rows.Close()
	
	var comments []models.Comment
	for rows.Next() {
		var c models.Comment
		var user models.User
		var userAvatarURL sql.NullString
		
		err := rows.Scan(
			&c.ID,
			&c.FaultID,
			&c.UserID,
			&c.Comment,
			&c.CreatedAt,
			&user.ID,
			&user.Email,
			&user.Name,
			&userAvatarURL,
			&user.CreatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("error scanning comment: %w", err)
		}
		
		if userAvatarURL.Valid {
			user.AvatarURL = &userAvatarURL.String
		}
		
		c.User = &user
		comments = append(comments, c)
	}
	
	return comments, nil
}

// GetUsers returns all users
func (r *Repository) GetUsers(ctx context.Context) ([]models.User, error) {
	query := `
		SELECT id, email, name, avatar_url, created_at
		FROM users
		ORDER BY name ASC
	`
	
	rows, err := r.pool.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("error getting users: %w", err)
	}
	defer rows.Close()
	
	var users []models.User
	for rows.Next() {
		var u models.User
		var avatarURL sql.NullString
		
		err := rows.Scan(
			&u.ID,
			&u.Email,
			&u.Name,
			&avatarURL,
			&u.CreatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("error scanning user: %w", err)
		}
		
		if avatarURL.Valid {
			u.AvatarURL = &avatarURL.String
		}
		
		users = append(users, u)
	}
	
	return users, nil
}

// CreateUser creates a new user
func (r *Repository) CreateUser(ctx context.Context, user *models.User) error {
	query := `
		INSERT INTO users (email, name, avatar_url)
		VALUES ($1, $2, $3)
		RETURNING id, created_at
	`
	
	err := r.pool.QueryRow(ctx, query, user.Email, user.Name, user.AvatarURL).Scan(
		&user.ID,
		&user.CreatedAt,
	)
	return err
}

// MergeFaults merges notices from source fault into target fault
func (r *Repository) MergeFaults(ctx context.Context, sourceFaultID, targetFaultID int64) error {
	// Update all notices to point to target fault
	query := `
		UPDATE notices
		SET fault_id = $1
		WHERE fault_id = $2
	`
	
	_, err := r.pool.Exec(ctx, query, targetFaultID, sourceFaultID)
	if err != nil {
		return fmt.Errorf("error updating notices: %w", err)
	}
	
	// Get stats for both faults
	sourceStats, err := r.GetFaultStats(ctx, sourceFaultID)
	if err != nil {
		return fmt.Errorf("error getting source fault stats: %w", err)
	}
	
	targetFault, err := r.GetFault(ctx, targetFaultID)
	if err != nil {
		return fmt.Errorf("error getting target fault: %w", err)
	}
	
	// Update target fault with merged data
	updates := map[string]interface{}{
		"occurrence_count": targetFault.OccurrenceCount + sourceStats.TotalOccurrences,
	}
	
	if sourceStats.FirstOccurred.Before(targetFault.FirstSeenAt) {
		updates["first_seen_at"] = sourceStats.FirstOccurred
	}
	if sourceStats.LastOccurred.After(targetFault.LastSeenAt) {
		updates["last_seen_at"] = sourceStats.LastOccurred
	}
	
	if err := r.UpdateFault(ctx, targetFaultID, updates); err != nil {
		return fmt.Errorf("error updating target fault: %w", err)
	}
	
	// Delete source fault
	return r.DeleteFault(ctx, sourceFaultID)
}

package models

import (
	"database/sql/driver"
	"encoding/json"
	"time"
)

// Fault represents an error group (similar to Honeybadger's fault concept)
type Fault struct {
	ID              int64      `json:"id" db:"id"`
	ProjectID       *int64     `json:"project_id,omitempty" db:"project_id"`
	ErrorClass      string     `json:"error_class" db:"error_class"`
	Message         string     `json:"message" db:"message"`
	Location        *string    `json:"location,omitempty" db:"location"`
	Environment     string     `json:"environment" db:"environment"`
	Resolved        bool       `json:"resolved" db:"resolved"`
	Ignored         bool       `json:"ignored" db:"ignored"`
	AssigneeID      *int64     `json:"assignee_id,omitempty" db:"assignee_id"`
	Assignee        *User      `json:"assignee,omitempty"`
	Tags            []string   `json:"tags" db:"tags"`
	Public          bool       `json:"public" db:"public"`
	OccurrenceCount int64      `json:"occurrence_count" db:"occurrence_count"`
	FirstSeenAt     time.Time  `json:"first_seen_at" db:"first_seen_at"`
	LastSeenAt      time.Time  `json:"last_seen_at" db:"last_seen_at"`
	CreatedAt       time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at" db:"updated_at"`
}

// StringArray is a custom type for PostgreSQL text arrays
type StringArray []string

// Value implements the driver.Valuer interface
func (a StringArray) Value() (driver.Value, error) {
	if len(a) == 0 {
		return "{}", nil
	}
	return json.Marshal(a)
}

// Scan implements the sql.Scanner interface
func (a *StringArray) Scan(value interface{}) error {
	if value == nil {
		*a = []string{}
		return nil
	}

	switch v := value.(type) {
	case []byte:
		return json.Unmarshal(v, a)
	case string:
		return json.Unmarshal([]byte(v), a)
	case []string:
		*a = v
		return nil
	default:
		return json.Unmarshal([]byte("[]"), a)
	}
}

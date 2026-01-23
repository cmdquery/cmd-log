package models

import "time"

// FaultHistory represents an audit trail entry for fault changes
type FaultHistory struct {
	ID        int64     `json:"id" db:"id"`
	FaultID   int64     `json:"fault_id" db:"fault_id"`
	Action    string    `json:"action" db:"action"` // resolved, assigned, tagged, etc.
	UserID    *int64    `json:"user_id,omitempty" db:"user_id"`
	User      *User     `json:"user,omitempty"`
	Revision  *string   `json:"revision,omitempty" db:"revision"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
}

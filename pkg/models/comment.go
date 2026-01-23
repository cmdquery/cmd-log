package models

import "time"

// Comment represents a comment on a fault
type Comment struct {
	ID        int64     `json:"id" db:"id"`
	FaultID   int64     `json:"fault_id" db:"fault_id"`
	UserID    int64     `json:"user_id" db:"user_id"`
	User      *User     `json:"user,omitempty"`
	Comment   string    `json:"comment" db:"comment"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
}

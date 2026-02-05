package models

import "time"

// User represents a user account
type User struct {
	ID           int64     `json:"id" db:"id"`
	Email        string    `json:"email" db:"email"`
	Name         string    `json:"name" db:"name"`
	AvatarURL    *string   `json:"avatar_url,omitempty" db:"avatar_url"`
	PasswordHash *string   `json:"-" db:"password_hash"`
	IsAdmin      bool      `json:"is_admin" db:"is_admin"`
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
}

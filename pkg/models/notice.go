package models

import "time"

// Notice represents an individual error occurrence
type Notice struct {
	ID          string                 `json:"id" db:"id"` // ULID
	FaultID     int64                  `json:"fault_id" db:"fault_id"`
	ProjectID   *int64                 `json:"project_id,omitempty" db:"project_id"`
	Message     string                 `json:"message" db:"message"`
	Backtrace   []BacktraceFrame       `json:"backtrace,omitempty" db:"backtrace"`
	Context     map[string]interface{} `json:"context,omitempty" db:"context"`
	Params      map[string]interface{} `json:"params,omitempty" db:"params"`
	Session     map[string]interface{} `json:"session,omitempty" db:"session"`
	Cookies     map[string]interface{} `json:"cookies,omitempty" db:"cookies"`
	Environment map[string]interface{} `json:"environment,omitempty" db:"environment"`
	Breadcrumbs []Breadcrumb           `json:"breadcrumbs,omitempty" db:"breadcrumbs"`
	Revision    *string                `json:"revision,omitempty" db:"revision"`
	Hostname    *string                `json:"hostname,omitempty" db:"hostname"`
	CreatedAt   time.Time              `json:"created_at" db:"created_at"`
}

// BacktraceFrame represents a single stack frame in a backtrace
type BacktraceFrame struct {
	File       string `json:"file"`
	Line       *int   `json:"line,omitempty"`
	Function   string `json:"function,omitempty"`
	Code       string `json:"code,omitempty"`
	Context    string `json:"context,omitempty"`
	Vars       map[string]interface{} `json:"vars,omitempty"`
}

// Breadcrumb represents an event in the breadcrumb trail
type Breadcrumb struct {
	Category string                 `json:"category"`
	Message  string                 `json:"message"`
	Metadata map[string]interface{} `json:"metadata,omitempty"`
	Time     time.Time              `json:"time"`
}

// NoticeRequest represents a Honeybadger-compatible notice request
type NoticeRequest struct {
	Notifier struct {
		Name    string `json:"name"`
		Version string `json:"version"`
		URL     string `json:"url"`
	} `json:"notifier"`
	Error struct {
		Class      string           `json:"class"`
		Message    string           `json:"message"`
		Backtrace []BacktraceFrame `json:"backtrace"`
	} `json:"error"`
	Request struct {
		URL        string                 `json:"url,omitempty"`
		Component  string                 `json:"component,omitempty"`
		Action     string                 `json:"action,omitempty"`
		Params     map[string]interface{} `json:"params,omitempty"`
		Session    map[string]interface{} `json:"session,omitempty"`
		Cookies    map[string]interface{} `json:"cookies,omitempty"`
		Context    map[string]interface{} `json:"context,omitempty"`
	} `json:"request,omitempty"`
	Server struct {
		EnvironmentName string                 `json:"environment_name,omitempty"`
		Hostname        string                 `json:"hostname,omitempty"`
		ProjectRoot     string                 `json:"project_root,omitempty"`
		Revision        string                 `json:"revision,omitempty"`
		Data            map[string]interface{} `json:"data,omitempty"`
	} `json:"server,omitempty"`
	Breadcrumbs struct {
		Enabled bool        `json:"enabled,omitempty"`
		Trail   []Breadcrumb `json:"trail,omitempty"`
	} `json:"breadcrumbs,omitempty"`
}

package auth

import (
	"context"
	"encoding/json"
	"log-ingestion-service/internal/storage"
	"os"
	"time"
)

// KeyManager manages API keys
type KeyManager struct {
	repository *storage.Repository
}

// NewKeyManager creates a new key manager
func NewKeyManager(repo *storage.Repository) *KeyManager {
	return &KeyManager{repository: repo}
}

// ValidateKey validates an API key against the database
func (km *KeyManager) ValidateKey(ctx context.Context, apiKey string) bool {
	// #region agent log
	if f, _ := os.OpenFile("/Users/moiz/Code/cmd-log/.cursor/debug.log", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644); f != nil {
		json.NewEncoder(f).Encode(map[string]interface{}{"sessionId": "debug-session", "runId": "run1", "hypothesisId": "A,B,C,D,E", "location": "key_manager.go:19", "message": "ValidateKey entry", "data": map[string]interface{}{"apiKey": apiKey, "apiKeyLength": len(apiKey)}, "timestamp": time.Now().UnixMilli()})
		f.Close()
	}
	// #endregion
	if apiKey == "" {
		return false
	}
	
	exists, err := km.repository.GetAPIKeyByValue(ctx, apiKey)
	// #region agent log
	if f, _ := os.OpenFile("/Users/moiz/Code/cmd-log/.cursor/debug.log", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644); f != nil {
		errStr := ""
		if err != nil {
			errStr = err.Error()
		}
		json.NewEncoder(f).Encode(map[string]interface{}{"sessionId": "debug-session", "runId": "run1", "hypothesisId": "A,B,D", "location": "key_manager.go:25", "message": "GetAPIKeyByValue returned", "data": map[string]interface{}{"exists": exists, "error": errStr}, "timestamp": time.Now().UnixMilli()})
		f.Close()
	}
	// #endregion
	if err != nil {
		// On error, fail closed (return false)
		return false
	}
	
	return exists
}

// GetKeys returns all valid API keys (for admin purposes)
func (km *KeyManager) GetKeys(ctx context.Context) ([]string, error) {
	return km.repository.GetAllActiveAPIKeys(ctx)
}


package auth

import (
	"context"
	"log-ingestion-service/internal/storage"
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
	if apiKey == "" {
		return false
	}
	
	exists, err := km.repository.GetAPIKeyByValue(ctx, apiKey)
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


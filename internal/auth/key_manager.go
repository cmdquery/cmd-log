package auth

import (
	"log-ingestion-service/pkg/config"
)

// KeyManager manages API keys
type KeyManager struct {
	config *config.AuthConfig
}

// NewKeyManager creates a new key manager
func NewKeyManager(cfg *config.AuthConfig) *KeyManager {
	return &KeyManager{config: cfg}
}

// ValidateKey validates an API key
func (km *KeyManager) ValidateKey(apiKey string) bool {
	if apiKey == "" {
		return false
	}
	
	for _, key := range km.config.APIKeys {
		if key == apiKey {
			return true
		}
	}
	
	return false
}

// GetKeys returns all valid API keys (for admin purposes)
func (km *KeyManager) GetKeys() []string {
	return km.config.APIKeys
}


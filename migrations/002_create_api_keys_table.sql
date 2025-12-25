-- Create api_keys table for storing API keys
CREATE TABLE IF NOT EXISTS api_keys (
    id BIGSERIAL PRIMARY KEY,
    key TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

-- Create index on key for fast lookups
CREATE INDEX IF NOT EXISTS idx_api_keys_key ON api_keys(key) WHERE is_active = TRUE;

-- Create index on is_active for filtering active keys
CREATE INDEX IF NOT EXISTS idx_api_keys_is_active ON api_keys(is_active);


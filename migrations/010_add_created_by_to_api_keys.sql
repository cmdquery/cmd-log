-- Add created_by_user_id column to api_keys table for ownership tracking
ALTER TABLE api_keys ADD COLUMN created_by_user_id BIGINT REFERENCES users(id);

-- Create index on created_by_user_id for efficient filtering by user
CREATE INDEX IF NOT EXISTS idx_api_keys_created_by ON api_keys(created_by_user_id);

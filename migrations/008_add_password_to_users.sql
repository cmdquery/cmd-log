-- Add password_hash column to users table for authentication
-- Nullable so existing assignee-only users still work
ALTER TABLE users ADD COLUMN password_hash TEXT;

-- Add is_admin flag to users table
-- Defaults to FALSE so existing users remain non-admin
ALTER TABLE users ADD COLUMN is_admin BOOLEAN NOT NULL DEFAULT FALSE;

-- Create fault_comments table - Comments on faults
CREATE TABLE IF NOT EXISTS fault_comments (
    id BIGSERIAL PRIMARY KEY,
    fault_id BIGINT NOT NULL REFERENCES faults(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    comment TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_fault_comments_fault_id ON fault_comments(fault_id);
CREATE INDEX IF NOT EXISTS idx_fault_comments_user_id ON fault_comments(user_id);
CREATE INDEX IF NOT EXISTS idx_fault_comments_created_at ON fault_comments(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fault_comments_fault_created ON fault_comments(fault_id, created_at DESC);

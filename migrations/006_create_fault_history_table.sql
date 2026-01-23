-- Create fault_history table - Audit trail for fault changes
CREATE TABLE IF NOT EXISTS fault_history (
    id BIGSERIAL PRIMARY KEY,
    fault_id BIGINT NOT NULL REFERENCES faults(id) ON DELETE CASCADE,
    action TEXT NOT NULL, -- resolved, assigned, tagged, etc.
    user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    revision TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_fault_history_fault_id ON fault_history(fault_id);
CREATE INDEX IF NOT EXISTS idx_fault_history_user_id ON fault_history(user_id);
CREATE INDEX IF NOT EXISTS idx_fault_history_created_at ON fault_history(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fault_history_fault_created ON fault_history(fault_id, created_at DESC);

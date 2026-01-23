-- Create faults table - Error groups (similar to Honeybadger's fault concept)
CREATE TABLE IF NOT EXISTS faults (
    id BIGSERIAL PRIMARY KEY,
    project_id BIGINT,
    error_class TEXT NOT NULL,
    message TEXT NOT NULL,
    location TEXT,
    environment TEXT NOT NULL,
    resolved BOOLEAN NOT NULL DEFAULT FALSE,
    ignored BOOLEAN NOT NULL DEFAULT FALSE,
    assignee_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    tags TEXT[] DEFAULT '{}',
    public BOOLEAN NOT NULL DEFAULT FALSE,
    occurrence_count BIGINT NOT NULL DEFAULT 0,
    first_seen_at TIMESTAMPTZ NOT NULL,
    last_seen_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS idx_faults_project_id ON faults(project_id);
CREATE INDEX IF NOT EXISTS idx_faults_error_class ON faults(error_class);
CREATE INDEX IF NOT EXISTS idx_faults_environment ON faults(environment);
CREATE INDEX IF NOT EXISTS idx_faults_resolved ON faults(resolved);
CREATE INDEX IF NOT EXISTS idx_faults_ignored ON faults(ignored);
CREATE INDEX IF NOT EXISTS idx_faults_assignee_id ON faults(assignee_id);
CREATE INDEX IF NOT EXISTS idx_faults_last_seen_at ON faults(last_seen_at DESC);
CREATE INDEX IF NOT EXISTS idx_faults_first_seen_at ON faults(first_seen_at);
CREATE INDEX IF NOT EXISTS idx_faults_tags ON faults USING GIN(tags);
CREATE INDEX IF NOT EXISTS idx_faults_error_class_location_env ON faults(error_class, location, environment);

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_faults_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_faults_updated_at
    BEFORE UPDATE ON faults
    FOR EACH ROW
    EXECUTE FUNCTION update_faults_updated_at();

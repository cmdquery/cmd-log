-- Create logs table
CREATE TABLE IF NOT EXISTS logs (
    id BIGSERIAL PRIMARY KEY,
    timestamp TIMESTAMPTZ NOT NULL,
    service VARCHAR(255) NOT NULL,
    level VARCHAR(50) NOT NULL,
    message TEXT NOT NULL,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_logs_timestamp ON logs (timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_logs_service ON logs (service);
CREATE INDEX IF NOT EXISTS idx_logs_level ON logs (level);
CREATE INDEX IF NOT EXISTS idx_logs_timestamp_service ON logs (timestamp DESC, service);

-- Convert to hypertable (TimescaleDB)
SELECT create_hypertable('logs', 'timestamp', if_not_exists => TRUE);

-- Create index on metadata for JSON queries (optional)
CREATE INDEX IF NOT EXISTS idx_logs_metadata ON logs USING GIN (metadata);


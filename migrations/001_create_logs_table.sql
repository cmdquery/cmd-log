-- Drop hypertable if it exists (this will also drop the underlying table)
SELECT drop_hypertable('logs', if_exists => TRUE);

-- Drop table if it exists (fallback if it's not a hypertable yet)
DROP TABLE IF EXISTS logs;

-- Create logs table
CREATE TABLE logs (
    id BIGSERIAL,
    timestamp TIMESTAMPTZ NOT NULL,
    service TEXT NOT NULL,
    level TEXT NOT NULL,
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


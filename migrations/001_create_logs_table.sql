-- Check if TimescaleDB extension is available and drop hypertable if it exists
DO $$
BEGIN
    -- Check if TimescaleDB extension exists
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'timescaledb') THEN
        -- Try to drop hypertable if it exists (this will also drop the underlying table)
        BEGIN
            PERFORM drop_hypertable('logs', if_exists => TRUE);
        EXCEPTION WHEN OTHERS THEN
            -- If drop_hypertable fails, table might not be a hypertable, continue
            NULL;
        END;
    END IF;
END $$;

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

-- Convert to hypertable (TimescaleDB) if extension is available
DO $$
BEGIN
    -- Check if TimescaleDB extension exists
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'timescaledb') THEN
        -- Create hypertable
        BEGIN
            PERFORM create_hypertable('logs', 'timestamp', if_not_exists => TRUE);
        EXCEPTION WHEN OTHERS THEN
            -- If create_hypertable fails, log error but continue
            RAISE NOTICE 'Could not create hypertable: %', SQLERRM;
        END;
    ELSE
        RAISE NOTICE 'TimescaleDB extension not found, using regular PostgreSQL table';
    END IF;
END $$;

-- Create index on metadata for JSON queries (optional)
CREATE INDEX IF NOT EXISTS idx_logs_metadata ON logs USING GIN (metadata);


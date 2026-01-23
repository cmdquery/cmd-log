-- Check if TimescaleDB extension is available and drop hypertable if it exists
DO $$
BEGIN
    -- Check if TimescaleDB extension exists
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'timescaledb') THEN
        -- Try to drop hypertable if it exists
        BEGIN
            PERFORM drop_hypertable('notices', if_exists => TRUE);
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
    END IF;
END $$;

-- Drop table if it exists (fallback if it's not a hypertable yet)
DROP TABLE IF EXISTS notices;

-- Create notices table - Individual error occurrences (hypertable for time-series)
CREATE TABLE notices (
    id TEXT PRIMARY KEY, -- ULID for distributed systems
    fault_id BIGINT NOT NULL REFERENCES faults(id) ON DELETE CASCADE,
    project_id BIGINT,
    message TEXT NOT NULL,
    backtrace JSONB,
    context JSONB,
    params JSONB,
    session JSONB,
    cookies JSONB,
    environment JSONB,
    breadcrumbs JSONB,
    revision TEXT,
    hostname TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_notices_fault_id ON notices(fault_id);
CREATE INDEX IF NOT EXISTS idx_notices_project_id ON notices(project_id);
CREATE INDEX IF NOT EXISTS idx_notices_created_at ON notices(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notices_fault_created ON notices(fault_id, created_at DESC);

-- Create GIN indexes for JSONB fields
CREATE INDEX IF NOT EXISTS idx_notices_backtrace ON notices USING GIN(backtrace);
CREATE INDEX IF NOT EXISTS idx_notices_context ON notices USING GIN(context);
CREATE INDEX IF NOT EXISTS idx_notices_breadcrumbs ON notices USING GIN(breadcrumbs);

-- Convert to hypertable (TimescaleDB) if extension is available
DO $$
BEGIN
    -- Check if TimescaleDB extension exists
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'timescaledb') THEN
        -- Create hypertable
        BEGIN
            PERFORM create_hypertable('notices', 'created_at', if_not_exists => TRUE);
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Could not create hypertable: %', SQLERRM;
        END;
    ELSE
        RAISE NOTICE 'TimescaleDB extension not found, using regular PostgreSQL table';
    END IF;
END $$;

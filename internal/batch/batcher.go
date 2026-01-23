package batch

import (
	"context"
	"log-ingestion-service/internal/storage"
	"log-ingestion-service/pkg/config"
	"log-ingestion-service/pkg/models"
	"sync"
	"time"
)

// Batcher collects log entries and flushes them in batches
type Batcher struct {
	repository    *storage.Repository
	config        *config.BatchConfig
	batch         []models.LogEntry
	mu            sync.Mutex
	flushTicker   *time.Ticker
	ctx           context.Context
	cancel        context.CancelFunc
	wg            sync.WaitGroup
	// Metrics
	totalProcessed int64
	flushCount     int64
	errorCount     int64
	startTime      time.Time
}

// NewBatcher creates a new batcher
func NewBatcher(repo *storage.Repository, cfg *config.BatchConfig) *Batcher {
	ctx, cancel := context.WithCancel(context.Background())
	
	b := &Batcher{
		repository:  repo,
		config:      cfg,
		batch:       make([]models.LogEntry, 0, cfg.Size),
		flushTicker: time.NewTicker(cfg.FlushInterval),
		ctx:         ctx,
		cancel:      cancel,
		startTime:   time.Now(),
	}
	
	// Start background flush routine
	b.wg.Add(1)
	go b.flushRoutine()
	
	return b
}

// Add adds a log entry to the batch
func (b *Batcher) Add(logEntry models.LogEntry) error {
	b.mu.Lock()
	defer b.mu.Unlock()
	
	b.batch = append(b.batch, logEntry)
	b.totalProcessed++
	
	// Flush if batch is full
	if len(b.batch) >= b.config.Size {
		return b.flushLocked()
	}
	
	return nil
}

// AddBatch adds multiple log entries to the batch
func (b *Batcher) AddBatch(logEntries []models.LogEntry) error {
	b.mu.Lock()
	defer b.mu.Unlock()
	
	b.batch = append(b.batch, logEntries...)
	b.totalProcessed += int64(len(logEntries))
	
	// Flush if batch is full
	if len(b.batch) >= b.config.Size {
		return b.flushLocked()
	}
	
	return nil
}

// Flush flushes the current batch
func (b *Batcher) Flush() error {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.flushLocked()
}

// flushLocked flushes the batch (must be called with lock held)
func (b *Batcher) flushLocked() error {
	if len(b.batch) == 0 {
		return nil
	}
	
	// Create a copy of the batch
	batchCopy := make([]models.LogEntry, len(b.batch))
	copy(batchCopy, b.batch)
	
	// Clear the batch
	b.batch = b.batch[:0]
	
	// Release lock before database operation
	b.mu.Unlock()
	
	// Insert batch into database
	err := b.repository.InsertBatch(b.ctx, batchCopy)
	
	// Re-acquire lock
	b.mu.Lock()
	
	// Update metrics
	b.flushCount++
	if err != nil {
		b.errorCount++
	}
	
	return err
}

// flushRoutine periodically flushes the batch
func (b *Batcher) flushRoutine() {
	defer b.wg.Done()
	
	for {
		select {
		case <-b.ctx.Done():
			// Final flush on shutdown
			b.Flush()
			return
		case <-b.flushTicker.C:
			b.Flush()
		}
	}
}

// Shutdown gracefully shuts down the batcher
func (b *Batcher) Shutdown() error {
	b.cancel()
	b.flushTicker.Stop()
	b.wg.Wait()
	return b.Flush()
}

// GetMetrics returns current batcher metrics
func (b *Batcher) GetMetrics() BatcherMetrics {
	b.mu.Lock()
	defer b.mu.Unlock()
	
	return BatcherMetrics{
		CurrentBatchSize: len(b.batch),
		TotalProcessed:   b.totalProcessed,
		FlushCount:       b.flushCount,
		ErrorCount:       b.errorCount,
		Uptime:           time.Since(b.startTime),
		Config:           *b.config,
	}
}

// BatcherMetrics holds batcher performance metrics
type BatcherMetrics struct {
	CurrentBatchSize int           `json:"current_batch_size"`
	TotalProcessed   int64         `json:"total_processed"`
	FlushCount       int64         `json:"flush_count"`
	ErrorCount       int64         `json:"error_count"`
	Uptime           time.Duration `json:"uptime"`
	Config           config.BatchConfig `json:"config"`
}

<template>
  <div class="log-detail-page">
    <div class="log-detail-header">
      <router-link to="/admin/logs" class="back-link">← Back to Logs</router-link>
      <h1 class="log-detail-title">Log Details</h1>
    </div>

    <div v-if="loading" class="loading-state">
      Loading log...
    </div>

    <div v-else-if="error" class="error-state">
      <p>{{ error }}</p>
      <router-link to="/admin/logs" class="btn btn-primary">Back to Logs</router-link>
    </div>

    <div v-else-if="log" class="log-detail-content">
      <!-- Header Section -->
      <div class="log-header-section">
        <div class="log-header-main">
          <span :class="['level-badge', `level-${log.level.toLowerCase()}`]">
            {{ log.level }}
          </span>
          <h2 class="log-message">{{ log.message }}</h2>
        </div>
        <div class="log-header-meta">
          <div class="meta-item">
            <span class="meta-label">Service:</span>
            <span class="meta-value">{{ log.service }}</span>
          </div>
          <div class="meta-item">
            <span class="meta-label">Timestamp:</span>
            <span class="meta-value">{{ formatTimestamp(log.timestamp) }}</span>
          </div>
          <div class="meta-item">
            <span class="meta-label">ID:</span>
            <span class="meta-value">{{ log.id }}</span>
          </div>
        </div>
      </div>

      <!-- Highlights Section -->
      <div class="log-section">
        <h3 class="section-title">Highlights</h3>
        <div class="highlights-grid">
          <div class="highlight-item">
            <span class="highlight-label">Level</span>
            <span :class="['highlight-value', `level-${log.level.toLowerCase()}`]">
              {{ log.level }}
            </span>
          </div>
          <div class="highlight-item">
            <span class="highlight-label">Service</span>
            <span class="highlight-value">{{ log.service }}</span>
          </div>
          <div class="highlight-item">
            <span class="highlight-label">Timestamp</span>
            <span class="highlight-value">{{ formatTimestamp(log.timestamp) }}</span>
          </div>
          <div class="highlight-item">
            <span class="highlight-label">ID</span>
            <span class="highlight-value">{{ log.id }}</span>
          </div>
        </div>
      </div>

      <!-- Metadata Section -->
      <div class="log-section" v-if="log.metadata && Object.keys(log.metadata).length > 0">
        <h3 class="section-title">Metadata</h3>
        <div class="metadata-container">
          <pre class="metadata-content">{{ formatMetadata(log.metadata) }}</pre>
        </div>
      </div>

      <!-- Details Section -->
      <div class="log-section">
        <h3 class="section-title">Details</h3>
        <div class="details-container">
          <div class="detail-row">
            <span class="detail-label">ID:</span>
            <span class="detail-value">{{ log.id }}</span>
          </div>
          <div class="detail-row">
            <span class="detail-label">Message:</span>
            <span class="detail-value">{{ log.message }}</span>
          </div>
          <div class="detail-row">
            <span class="detail-label">Level:</span>
            <span :class="['detail-value', `level-${log.level.toLowerCase()}`]">
              {{ log.level }}
            </span>
          </div>
          <div class="detail-row">
            <span class="detail-label">Service:</span>
            <span class="detail-value">{{ log.service }}</span>
          </div>
          <div class="detail-row">
            <span class="detail-label">Timestamp:</span>
            <span class="detail-value">{{ formatTimestamp(log.timestamp) }}</span>
          </div>
          <div class="detail-row">
            <span class="detail-label">ISO Timestamp:</span>
            <span class="detail-value">{{ log.timestamp }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { getLogById } from '../services/api'

const route = useRoute()
const log = ref(null)
const loading = ref(true)
const error = ref(null)

const formatTimestamp = (timestamp) => {
  return new Date(timestamp).toLocaleString()
}

const formatMetadata = (metadata) => {
  if (typeof metadata === 'string') {
    try {
      return JSON.stringify(JSON.parse(metadata), null, 2)
    } catch {
      return metadata
    }
  }
  return JSON.stringify(metadata, null, 2)
}

const loadLog = async () => {
  loading.value = true
  error.value = null
  try {
    const logId = route.params.id
    const data = await getLogById(logId)
    log.value = data
  } catch (err) {
    console.error('Error loading log:', err)
    error.value = err.message || 'Failed to load log'
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  loadLog()
})
</script>

<style scoped>
.log-detail-page {
  padding: 1rem 0;
}

.log-detail-header {
  margin-bottom: 1.5rem;
}

.back-link {
  display: inline-block;
  color: #666;
  text-decoration: none;
  margin-bottom: 0.5rem;
  font-size: 0.9rem;
}

.back-link:hover {
  color: #333;
  text-decoration: underline;
}

.log-detail-title {
  margin: 0;
  font-size: 1.5rem;
  color: #2c3e50;
}

.loading-state,
.error-state {
  text-align: center;
  padding: 2rem;
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.error-state {
  color: #721c24;
}

.log-detail-content {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.log-header-section {
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  padding: 1.5rem;
}

.log-header-main {
  display: flex;
  align-items: center;
  gap: 1rem;
  margin-bottom: 1rem;
}

.log-message {
  margin: 0;
  font-size: 1.25rem;
  font-weight: 600;
  color: #2c3e50;
  flex: 1;
}

.log-header-meta {
  display: flex;
  gap: 2rem;
  flex-wrap: wrap;
  padding-top: 1rem;
  border-top: 1px solid #dee2e6;
}

.meta-item {
  display: flex;
  gap: 0.5rem;
}

.meta-label {
  font-weight: 600;
  color: #666;
}

.meta-value {
  color: #2c3e50;
}

.log-section {
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  padding: 1.5rem;
}

.section-title {
  margin: 0 0 1rem 0;
  font-size: 1.1rem;
  font-weight: 600;
  color: #2c3e50;
  border-bottom: 2px solid #dee2e6;
  padding-bottom: 0.5rem;
}

.highlights-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 1rem;
}

.highlight-item {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.highlight-label {
  font-size: 0.85rem;
  color: #666;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.highlight-value {
  font-size: 1rem;
  font-weight: 600;
  color: #2c3e50;
}

.metadata-container {
  background: #f8f9fa;
  border: 1px solid #dee2e6;
  border-radius: 4px;
  padding: 1rem;
  overflow-x: auto;
}

.metadata-content {
  margin: 0;
  font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', 'Consolas', monospace;
  font-size: 0.9rem;
  line-height: 1.5;
  color: #2c3e50;
  white-space: pre-wrap;
  word-wrap: break-word;
}

.details-container {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.detail-row {
  display: grid;
  grid-template-columns: 150px 1fr;
  gap: 1rem;
  padding: 0.75rem 0;
  border-bottom: 1px solid #f0f0f0;
}

.detail-row:last-child {
  border-bottom: none;
}

.detail-label {
  font-weight: 600;
  color: #666;
}

.detail-value {
  color: #2c3e50;
  word-break: break-word;
}

.level-badge {
  display: inline-block;
  padding: 0.375rem 0.75rem;
  border-radius: 4px;
  font-size: 0.85rem;
  font-weight: 600;
  text-transform: uppercase;
}

.level-badge.level-info {
  background-color: #e3f2fd;
  color: #1976d2;
}

.level-badge.level-warn,
.level-badge.level-warning {
  background-color: #fff3cd;
  color: #856404;
}

.level-badge.level-error {
  background-color: #f8d7da;
  color: #721c24;
}

.level-badge.level-debug {
  background-color: #e2e3e5;
  color: #383d41;
}

.level-badge.level-fatal,
.level-badge.level-critical {
  background-color: #721c24;
  color: #fff;
}

.highlight-value.level-error,
.detail-value.level-error {
  color: #721c24;
}

.highlight-value.level-warn,
.detail-value.level-warn,
.highlight-value.level-warning,
.detail-value.level-warning {
  color: #856404;
}

.highlight-value.level-info,
.detail-value.level-info {
  color: #1976d2;
}

.btn {
  display: inline-block;
  padding: 0.5rem 1rem;
  border-radius: 4px;
  text-decoration: none;
  font-weight: 500;
  cursor: pointer;
  border: none;
  font-size: 0.9rem;
}

.btn-primary {
  background-color: #007bff;
  color: white;
}

.btn-primary:hover {
  background-color: #0056b3;
}
</style>


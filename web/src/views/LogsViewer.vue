<template>
  <div class="logs-page">
    <h2 class="page-title">Recent Logs</h2>
    
    <div class="logs-controls">
      <button @click="loadLogs" class="btn btn-primary">Refresh</button>
      <label>
        Limit:
        <select v-model="limit" @change="loadLogs">
          <option value="50">50</option>
          <option value="100">100</option>
          <option value="200">200</option>
          <option value="500">500</option>
        </select>
      </label>
      <label>
        Auto-refresh:
        <input type="checkbox" v-model="autoRefresh" @change="toggleAutoRefresh" />
      </label>
    </div>
    
    <div class="logs-list-container">
      <div v-if="loading" class="loading-state">
        Loading logs...
      </div>
      <div v-else-if="logs.length === 0" class="empty-state">
        No logs found
      </div>
      <div
        v-else
        v-for="log in logs"
        :key="log.id"
        @click="navigateToLog(log.id)"
        :class="['log-row', `level-${log.level.toLowerCase()}`]"
      >
        <div class="log-row-indicator" :class="`level-${log.level.toLowerCase()}`"></div>
        <div class="log-row-content">
          <div class="log-row-main">
            <span :class="['level-badge', `level-${log.level.toLowerCase()}`]">
              {{ log.level }}
            </span>
            <div class="log-message-preview">
              {{ truncateMessage(log.message) }}
            </div>
          </div>
          <div class="log-row-meta">
            <span class="log-service">{{ log.service }}</span>
            <span class="log-timestamp">{{ formatRelativeTime(log.timestamp) }}</span>
            <span v-if="hasMetadata(log)" class="log-metadata-indicator" title="Has metadata">
              <svg width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M8 2C4.7 2 2 4.7 2 8C2 11.3 4.7 14 8 14C11.3 14 14 11.3 14 8C14 4.7 11.3 2 8 2ZM8 13C5.2 13 3 10.8 3 8C3 5.2 5.2 3 8 3C10.8 3 13 5.2 13 8C13 10.8 10.8 13 8 13Z" fill="currentColor"/>
                <path d="M8 5C7.4 5 7 5.4 7 6C7 6.6 7.4 7 8 7C8.6 7 9 6.6 9 6C9 5.4 8.6 5 8 5ZM9 9H7V11H9V9Z" fill="currentColor"/>
              </svg>
            </span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { getRecentLogs } from '../services/api'

const router = useRouter()
const logs = ref([])
const loading = ref(false)
const limit = ref(100)
const autoRefresh = ref(true)
let autoRefreshInterval = null

const formatRelativeTime = (timestamp) => {
  const now = new Date()
  const time = new Date(timestamp)
  const diffMs = now - time
  const diffSecs = Math.floor(diffMs / 1000)
  const diffMins = Math.floor(diffSecs / 60)
  const diffHours = Math.floor(diffMins / 60)
  const diffDays = Math.floor(diffHours / 24)

  if (diffSecs < 60) {
    return 'just now'
  } else if (diffMins < 60) {
    return `${diffMins}m ago`
  } else if (diffHours < 24) {
    return `${diffHours}hr ago`
  } else if (diffDays < 7) {
    return `${diffDays}d ago`
  } else {
    return time.toLocaleDateString()
  }
}

const truncateMessage = (message) => {
  if (!message) return ''
  const maxLength = 120
  if (message.length <= maxLength) return message
  return message.substring(0, maxLength) + '...'
}

const hasMetadata = (log) => {
  return log.metadata && Object.keys(log.metadata).length > 0
}

const navigateToLog = (id) => {
  router.push(`/admin/logs/${id}`)
}

const loadLogs = async () => {
  loading.value = true
  try {
    const data = await getRecentLogs(limit.value)
    logs.value = data.logs || []
  } catch (error) {
    console.error('Error loading logs:', error)
    logs.value = []
  } finally {
    loading.value = false
  }
}

const toggleAutoRefresh = () => {
  if (autoRefresh.value) {
    startAutoRefresh()
  } else {
    stopAutoRefresh()
  }
}

const startAutoRefresh = () => {
  if (autoRefreshInterval) {
    clearInterval(autoRefreshInterval)
  }
  autoRefreshInterval = setInterval(loadLogs, 5000)
}

const stopAutoRefresh = () => {
  if (autoRefreshInterval) {
    clearInterval(autoRefreshInterval)
    autoRefreshInterval = null
  }
}

onMounted(() => {
  loadLogs()
  if (autoRefresh.value) {
    startAutoRefresh()
  }
})

onUnmounted(() => {
  stopAutoRefresh()
})
</script>

<style scoped>
.logs-page {
  padding: 1rem 0;
}

.page-title {
  margin: 0 0 1.5rem 0;
  font-size: 1.5rem;
  color: #2c3e50;
}

.logs-controls {
  display: flex;
  gap: 1rem;
  align-items: center;
  margin-bottom: 1rem;
  padding: 1rem;
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.logs-controls label {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.logs-controls select {
  padding: 0.5rem;
  border: 1px solid #ddd;
  border-radius: 4px;
}

.btn {
  padding: 0.5rem 1rem;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-weight: 500;
  font-size: 0.9rem;
}

.btn-primary {
  background-color: #007bff;
  color: white;
}

.btn-primary:hover {
  background-color: #0056b3;
}

.logs-list-container {
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  overflow: hidden;
}

.loading-state,
.empty-state {
  padding: 2rem;
  text-align: center;
  color: #666;
}

.log-row {
  display: flex;
  align-items: stretch;
  cursor: pointer;
  border-bottom: 1px solid #e9ecef;
  transition: background-color 0.15s ease;
  position: relative;
}

.log-row:last-child {
  border-bottom: none;
}

.log-row:hover {
  background-color: #f8f9fa;
}

.log-row-indicator {
  width: 4px;
  flex-shrink: 0;
  background-color: #e9ecef;
}

.log-row-indicator.level-error,
.log-row-indicator.level-fatal,
.log-row-indicator.level-critical {
  background-color: #dc3545;
}

.log-row-indicator.level-warn,
.log-row-indicator.level-warning {
  background-color: #ffc107;
}

.log-row-indicator.level-info {
  background-color: #17a2b8;
}

.log-row-indicator.level-debug {
  background-color: #6c757d;
}

.log-row-content {
  flex: 1;
  padding: 0.875rem 1rem;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.log-row-main {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.level-badge {
  display: inline-flex;
  align-items: center;
  padding: 0.25rem 0.5rem;
  border-radius: 4px;
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.3px;
  flex-shrink: 0;
  min-width: 60px;
  justify-content: center;
}

.level-badge.level-info {
  background-color: #d1ecf1;
  color: #0c5460;
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

.level-badge.level-fatal,
.level-badge.level-critical {
  background-color: #721c24;
  color: #fff;
}

.level-badge.level-debug {
  background-color: #e2e3e5;
  color: #383d41;
}

.log-message-preview {
  flex: 1;
  font-size: 0.9rem;
  color: #2c3e50;
  line-height: 1.4;
  word-break: break-word;
}

.log-row-meta {
  display: flex;
  align-items: center;
  gap: 1rem;
  font-size: 0.8rem;
  color: #6c757d;
}

.log-service {
  font-weight: 500;
  color: #495057;
}

.log-timestamp {
  color: #6c757d;
}

.log-metadata-indicator {
  display: flex;
  align-items: center;
  color: #6c757d;
  margin-left: auto;
}

.log-metadata-indicator svg {
  width: 14px;
  height: 14px;
}

/* Subtle background tinting for error/warn rows */
.log-row.level-error {
  background-color: rgba(220, 53, 69, 0.03);
}

.log-row.level-error:hover {
  background-color: rgba(220, 53, 69, 0.08);
}

.log-row.level-warn,
.log-row.level-warning {
  background-color: rgba(255, 193, 7, 0.03);
}

.log-row.level-warn:hover,
.log-row.level-warning:hover {
  background-color: rgba(255, 193, 7, 0.08);
}
</style>

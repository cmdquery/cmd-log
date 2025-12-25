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
    
    <div class="logs-table-container">
      <table class="logs-table">
        <thead>
          <tr>
            <th>Timestamp</th>
            <th>Service</th>
            <th>Level</th>
            <th>Message</th>
            <th>Metadata</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="loading">
            <td colspan="5" class="loading">Loading logs...</td>
          </tr>
          <tr v-else-if="logs.length === 0">
            <td colspan="5" class="empty">No logs found</td>
          </tr>
          <tr
            v-else
            v-for="log in logs"
            :key="log.id"
            :class="['log-row', `level-${log.level.toLowerCase()}`]"
          >
            <td>{{ formatTimestamp(log.timestamp) }}</td>
            <td>{{ log.service }}</td>
            <td>
              <span :class="['level-badge', `level-${log.level.toLowerCase()}`]">
                {{ log.level }}
              </span>
            </td>
            <td>{{ log.message }}</td>
            <td>
              <pre v-if="log.metadata" class="metadata">{{ formatMetadata(log.metadata) }}</pre>
              <span v-else>-</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { getRecentLogs } from '../services/api'

const logs = ref([])
const loading = ref(false)
const limit = ref(100)
const autoRefresh = ref(true)
let autoRefreshInterval = null

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

.logs-table-container {
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  overflow-x: auto;
}

.logs-table {
  width: 100%;
  border-collapse: collapse;
}

.logs-table th {
  background-color: #f8f9fa;
  padding: 1rem;
  text-align: left;
  font-weight: 600;
  color: #2c3e50;
  border-bottom: 2px solid #dee2e6;
}

.logs-table td {
  padding: 0.75rem 1rem;
  border-bottom: 1px solid #dee2e6;
}

.logs-table tr:hover {
  background-color: #f8f9fa;
}

.log-row.level-error {
  background-color: #fee;
}

.log-row.level-warn {
  background-color: #fff8e1;
}

.level-badge {
  display: inline-block;
  padding: 0.25rem 0.5rem;
  border-radius: 4px;
  font-size: 0.85rem;
  font-weight: 600;
  text-transform: uppercase;
}

.level-badge.level-info {
  background-color: #e3f2fd;
  color: #1976d2;
}

.level-badge.level-warn {
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

.metadata {
  font-size: 0.85rem;
  max-width: 300px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>


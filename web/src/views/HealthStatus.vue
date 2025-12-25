<template>
  <div class="health-page">
    <h2 class="page-title">Health Status</h2>
    
    <div v-if="loading" class="loading">Loading health status...</div>
    <div v-else-if="error" class="error">{{ error }}</div>
    <div v-else>
      <div class="health-section">
        <div class="health-status" :class="health.status">
          <span class="status-indicator" :class="health.status">●</span>
          <h3>Overall Status: {{ health.status }}</h3>
        </div>
        <p>Uptime: {{ health.uptime }}</p>
      </div>
      
      <div class="health-section">
        <h3>Database</h3>
        <div class="health-item">
          <span class="status-indicator" :class="health.database?.healthy ? 'healthy' : 'error'">●</span>
          <span>{{ health.database?.healthy ? 'Healthy' : 'Unhealthy' }}</span>
        </div>
        <div v-if="health.database?.error" class="health-details">
          <p class="error-message">{{ health.database.error }}</p>
        </div>
      </div>
      
      <div class="health-section">
        <h3>Batcher</h3>
        <div class="health-item">
          <span class="status-indicator" :class="health.batcher?.healthy ? 'healthy' : 'error'">●</span>
          <span>{{ health.batcher?.healthy ? 'Healthy' : 'Unhealthy' }}</span>
        </div>
        <div class="health-details">
          <p>Current Batch: {{ health.batcher?.current_batch || 0 }}</p>
          <p>Total Processed: {{ formatNumber(health.batcher?.total_processed || 0) }}</p>
          <p>Flush Count: {{ health.batcher?.flush_count || 0 }}</p>
          <p>Error Count: {{ health.batcher?.error_count || 0 }}</p>
          <p>Uptime: {{ health.batcher?.uptime || '-' }}</p>
        </div>
      </div>
      
      <div class="health-section">
        <h3>Configuration</h3>
        <div class="health-details">
          <p>Batch Size: {{ health.config?.batch_size || '-' }}</p>
          <p>Batch Flush Interval: {{ health.config?.batch_flush_interval || '-' }}</p>
          <p>Rate Limit Enabled: {{ health.config?.rate_limit_enabled ? 'Yes' : 'No' }}</p>
          <p>Rate Limit RPS: {{ health.config?.rate_limit_rps || '-' }}</p>
        </div>
      </div>
      
      <div class="health-actions">
        <button @click="loadHealth" class="btn btn-primary">Refresh</button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { getHealth } from '../services/api'

const health = ref({})
const loading = ref(false)
const error = ref('')

const formatNumber = (num) => {
  return num.toLocaleString()
}

const loadHealth = async () => {
  loading.value = true
  error.value = ''
  try {
    health.value = await getHealth()
  } catch (err) {
    error.value = err.message || 'Failed to load health status'
    console.error('Error loading health:', err)
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  loadHealth()
})
</script>

<style scoped>
.health-page {
  background: white;
  padding: 2rem;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.health-section {
  margin-bottom: 2rem;
  padding-bottom: 2rem;
  border-bottom: 1px solid #dee2e6;
}

.health-section:last-child {
  border-bottom: none;
}

.health-section h3 {
  margin-bottom: 1rem;
  color: #2c3e50;
}

.health-status {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 1.5rem;
  font-weight: 600;
  margin-bottom: 0.5rem;
}

.health-status.healthy {
  color: #27ae60;
}

.health-status.unhealthy {
  color: #e74c3c;
}

.status-indicator {
  display: inline-block;
  font-size: 1.5rem;
}

.status-indicator.healthy {
  color: #27ae60;
}

.status-indicator.error {
  color: #e74c3c;
}

.health-item {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.5rem;
}

.health-details {
  margin-top: 1rem;
  padding-left: 1.5rem;
}

.health-details p {
  margin: 0.5rem 0;
  color: #666;
}

.error-message {
  background-color: #fee;
  color: #721c24;
  padding: 1rem;
  border-radius: 4px;
  margin: 1rem 0;
}

.health-actions {
  margin-top: 2rem;
  display: flex;
  gap: 1rem;
}
</style>


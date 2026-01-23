<template>
  <div class="health-page">
    <div class="section__header mb-6">
      <h1 class="page-title mb-0">Health Status</h1>
      <button @click="loadHealth" class="btn btn--primary">
        <span>↻</span> Refresh
      </button>
    </div>
    
    <div v-if="loading" class="loading-spinner">
      <div class="spinner"></div>
    </div>
    
    <div v-else-if="error" class="card card--empty">
      <div class="card__icon">⚠️</div>
      <div class="card__text">{{ error }}</div>
      <button @click="loadHealth" class="btn btn--primary">Retry</button>
    </div>
    
    <div v-else class="health-grid">
      <!-- Overall Status -->
      <div class="health-card">
        <div class="health-card__header">
          <h3 class="health-card__title">Overall Status</h3>
          <div class="health-card__status" :class="health.status === 'healthy' ? 'is-healthy' : 'is-unhealthy'">
            <span class="health-card__dot"></span>
            {{ health.status === 'healthy' ? 'Healthy' : 'Unhealthy' }}
          </div>
        </div>
        <div class="health-card__metrics">
          <div class="health-metric">
            <span class="health-metric__label">Uptime</span>
            <span class="health-metric__value">{{ health.uptime || '—' }}</span>
          </div>
        </div>
      </div>
      
      <!-- Database -->
      <div class="health-card">
        <div class="health-card__header">
          <h3 class="health-card__title">Database</h3>
          <div class="health-card__status" :class="health.database?.healthy ? 'is-healthy' : 'is-unhealthy'">
            <span class="health-card__dot"></span>
            {{ health.database?.healthy ? 'Healthy' : 'Unhealthy' }}
          </div>
        </div>
        <div v-if="health.database?.error" class="alert alert--error mt-4">
          {{ health.database.error }}
        </div>
      </div>
      
      <!-- Batcher -->
      <div class="health-card">
        <div class="health-card__header">
          <h3 class="health-card__title">Batcher</h3>
          <div class="health-card__status" :class="health.batcher?.healthy ? 'is-healthy' : 'is-unhealthy'">
            <span class="health-card__dot"></span>
            {{ health.batcher?.healthy ? 'Healthy' : 'Unhealthy' }}
          </div>
        </div>
        <div class="health-card__metrics">
          <div class="health-metric">
            <span class="health-metric__label">Current Batch</span>
            <span class="health-metric__value">{{ health.batcher?.current_batch || 0 }}</span>
          </div>
          <div class="health-metric">
            <span class="health-metric__label">Total Processed</span>
            <span class="health-metric__value">{{ formatNumber(health.batcher?.total_processed || 0) }}</span>
          </div>
          <div class="health-metric">
            <span class="health-metric__label">Flush Count</span>
            <span class="health-metric__value">{{ health.batcher?.flush_count || 0 }}</span>
          </div>
          <div class="health-metric">
            <span class="health-metric__label">Error Count</span>
            <span class="health-metric__value">{{ health.batcher?.error_count || 0 }}</span>
          </div>
          <div class="health-metric">
            <span class="health-metric__label">Uptime</span>
            <span class="health-metric__value">{{ health.batcher?.uptime || '—' }}</span>
          </div>
        </div>
      </div>
      
      <!-- Configuration -->
      <div class="health-card">
        <div class="health-card__header">
          <h3 class="health-card__title">Configuration</h3>
        </div>
        <div class="health-card__metrics">
          <div class="health-metric">
            <span class="health-metric__label">Batch Size</span>
            <span class="health-metric__value">{{ health.config?.batch_size || '—' }}</span>
          </div>
          <div class="health-metric">
            <span class="health-metric__label">Flush Interval</span>
            <span class="health-metric__value">{{ health.config?.batch_flush_interval || '—' }}</span>
          </div>
          <div class="health-metric">
            <span class="health-metric__label">Rate Limit</span>
            <span class="health-metric__value">
              <span :class="['badge badge--xs', health.config?.rate_limit_enabled ? 'badge--success' : 'badge--pending']">
                {{ health.config?.rate_limit_enabled ? 'Enabled' : 'Disabled' }}
              </span>
            </span>
          </div>
          <div class="health-metric">
            <span class="health-metric__label">Rate Limit RPS</span>
            <span class="health-metric__value">{{ health.config?.rate_limit_rps || '—' }}</span>
          </div>
        </div>
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
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  loadHealth()
})
</script>

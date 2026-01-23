<template>
  <div class="log-detail-page">
    <div class="mb-6">
      <router-link to="/logs" class="btn btn--ghost btn--sm mb-4">
        ← Back to Logs
      </router-link>
      <h1 class="page-title mb-0">Log Details</h1>
    </div>

    <div v-if="loading" class="loading-spinner">
      <div class="spinner"></div>
    </div>

    <div v-else-if="error" class="card card--empty">
      <div class="card__icon">⚠️</div>
      <div class="card__text">{{ error }}</div>
      <router-link to="/logs" class="btn btn--primary">Back to Logs</router-link>
    </div>

    <div v-else-if="log" class="flex flex-col gap-6">
      <!-- Header Section -->
      <div class="card">
        <div class="flex items-center gap-4 mb-4">
          <span :class="['badge', `badge--${log.level.toLowerCase()}`]">
            {{ log.level }}
          </span>
          <h2 class="h4 mb-0">{{ log.message }}</h2>
        </div>
        <div class="detail-grid">
          <div class="detail-item">
            <div class="detail-label">Service</div>
            <div class="detail-value">{{ log.service }}</div>
          </div>
          <div class="detail-item">
            <div class="detail-label">Timestamp</div>
            <div class="detail-value">{{ formatTimestamp(log.timestamp) }}</div>
          </div>
          <div class="detail-item">
            <div class="detail-label">ID</div>
            <div class="detail-value code">{{ log.id }}</div>
          </div>
        </div>
      </div>

      <!-- Highlights Section -->
      <div class="card">
        <div class="card__header">
          <h3 class="h5">Highlights</h3>
        </div>
        <div class="detail-grid">
          <div class="detail-item">
            <div class="detail-label">Level</div>
            <div class="detail-value">
              <span :class="['badge', `badge--${log.level.toLowerCase()}`]">
                {{ log.level }}
              </span>
            </div>
          </div>
          <div class="detail-item">
            <div class="detail-label">Service</div>
            <div class="detail-value">{{ log.service }}</div>
          </div>
          <div class="detail-item">
            <div class="detail-label">Timestamp</div>
            <div class="detail-value">{{ formatTimestamp(log.timestamp) }}</div>
          </div>
          <div class="detail-item">
            <div class="detail-label">ID</div>
            <div class="detail-value code">{{ log.id }}</div>
          </div>
        </div>
      </div>

      <!-- Metadata Section -->
      <div class="card" v-if="log.metadata && Object.keys(log.metadata).length > 0">
        <div class="card__header">
          <h3 class="h5">Metadata</h3>
        </div>
        <div class="code-block">
          <div class="code-block__content">
            <pre>{{ formatMetadata(log.metadata) }}</pre>
          </div>
        </div>
      </div>

      <!-- Details Section -->
      <div class="card">
        <div class="card__header">
          <h3 class="h5">Details</h3>
        </div>
        <div class="flex flex-col">
          <div class="flex justify-between py-3" style="border-bottom: 1px solid var(--border-primary)">
            <span class="text-muted">ID</span>
            <span class="code">{{ log.id }}</span>
          </div>
          <div class="flex justify-between py-3" style="border-bottom: 1px solid var(--border-primary)">
            <span class="text-muted">Message</span>
            <span class="text-truncate" style="max-width: 400px">{{ log.message }}</span>
          </div>
          <div class="flex justify-between py-3" style="border-bottom: 1px solid var(--border-primary)">
            <span class="text-muted">Level</span>
            <span :class="['badge', `badge--${log.level.toLowerCase()}`]">{{ log.level }}</span>
          </div>
          <div class="flex justify-between py-3" style="border-bottom: 1px solid var(--border-primary)">
            <span class="text-muted">Service</span>
            <span>{{ log.service }}</span>
          </div>
          <div class="flex justify-between py-3" style="border-bottom: 1px solid var(--border-primary)">
            <span class="text-muted">Timestamp</span>
            <span>{{ formatTimestamp(log.timestamp) }}</span>
          </div>
          <div class="flex justify-between py-3">
            <span class="text-muted">ISO Timestamp</span>
            <span class="code">{{ log.timestamp }}</span>
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
    error.value = err.message || 'Failed to load log'
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  loadLog()
})
</script>

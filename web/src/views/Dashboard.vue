<template>
  <div class="dashboard">
    <h2 class="page-title">Dashboard</h2>
    
    <div class="metrics-grid">
      <MetricCard title="Service Status" :value="healthStatus">
        <template #content>
          <div class="flex items-center gap-2">
            <span class="status-indicator" :class="healthStatusClass">●</span>
            <span class="text-body-sm">{{ healthStatusText }}</span>
          </div>
        </template>
      </MetricCard>
      
      <MetricCard title="Logs Per Second" :value="metrics.logs?.per_second?.toFixed(2) || '-'" />
      
      <MetricCard title="Total Logs (24h)" :value="formatNumber(metrics.logs?.total || 0)" />
      
      <MetricCard title="Recent Errors (1h)">
        <template #content>
          <div class="metric-card__value">{{ metrics.logs?.recent_errors || 0 }}</div>
          <span v-if="metrics.logs?.recent_errors > 0" class="error-badge">
            {{ metrics.logs?.recent_errors || 0 }} errors
          </span>
        </template>
      </MetricCard>
      
      <MetricCard title="Batch Status">
        <template #content>
          <div class="flex flex-col gap-2 text-body-sm">
            <div class="flex justify-between">
              <span class="text-muted">Current:</span>
              <span>{{ metrics.batcher?.current_batch_size || '-' }}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-muted">Processed:</span>
              <span>{{ formatNumber(metrics.batcher?.total_processed || 0) }}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-muted">Flushes:</span>
              <span>{{ metrics.batcher?.flush_count || '-' }}</span>
            </div>
          </div>
        </template>
      </MetricCard>
      
      <MetricCard title="Uptime" :value="metrics.uptime || '-'" />
    </div>
    
    <div class="charts-section">
      <div class="chart-card">
        <h3>Log Volume Over Time</h3>
        <canvas ref="volumeChartRef"></canvas>
      </div>
      
      <div class="chart-card">
        <h3>Logs by Service</h3>
        <canvas ref="serviceChartRef"></canvas>
      </div>
      
      <div class="chart-card">
        <h3>Logs by Level</h3>
        <canvas ref="levelChartRef"></canvas>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, computed } from 'vue'
import { Chart, registerables } from 'chart.js'
import { getMetrics, getHealth } from '../services/api'
import MetricCard from '../components/MetricCard.vue'

Chart.register(...registerables)

const metrics = ref({})
const health = ref({})
const volumeChartRef = ref(null)
const serviceChartRef = ref(null)
const levelChartRef = ref(null)

let volumeChart = null
let serviceChart = null
let levelChart = null
let refreshInterval = null

const healthStatus = ref('Checking...')
const healthStatusText = ref('Checking...')
const healthStatusClass = ref('')

const formatNumber = (num) => {
  return num.toLocaleString()
}

// Get chart colors based on theme
const getChartColors = () => {
  const isDark = document.documentElement.classList.contains('dark')
  return {
    text: isDark ? '#d0d6e0' : '#4a4a4a',
    grid: isDark ? '#23252a' : '#e5e5e5',
    background: isDark ? '#141516' : '#f5f5f5'
  }
}

const loadData = async () => {
  try {
    const [metricsData, healthData] = await Promise.all([
      getMetrics('24h', '5m'),
      getHealth()
    ])
    
    metrics.value = metricsData
    health.value = healthData
    
    if (healthData.status === 'healthy') {
      healthStatus.value = 'Healthy'
      healthStatusText.value = 'All systems operational'
      healthStatusClass.value = 'healthy'
    } else {
      healthStatus.value = 'Unhealthy'
      healthStatusText.value = 'Issues detected'
      healthStatusClass.value = 'error'
    }
    
    updateCharts(metricsData)
  } catch (error) {
    console.error('Error loading dashboard data:', error)
    healthStatus.value = 'Error'
    healthStatusText.value = 'Connection failed'
    healthStatusClass.value = 'error'
  }
}

const updateCharts = (data) => {
  const colors = getChartColors()
  
  // Chart.js default options for dark mode
  const defaultOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        labels: {
          color: colors.text
        }
      }
    }
  }
  
  // Volume chart
  if (volumeChartRef.value) {
    const ctx = volumeChartRef.value.getContext('2d')
    if (volumeChart) {
      volumeChart.destroy()
    }
    
    const timeLabels = (data.time_series || []).map(p => {
      const date = new Date(p.time)
      return date.toLocaleTimeString()
    })
    const timeData = (data.time_series || []).map(p => p.count)
    
    volumeChart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: timeLabels,
        datasets: [{
          label: 'Logs',
          data: timeData,
          borderColor: '#5e6ad2',
          backgroundColor: 'rgba(94, 106, 210, 0.1)',
          fill: true,
          tension: 0.4
        }]
      },
      options: {
        ...defaultOptions,
        scales: {
          y: {
            beginAtZero: true,
            grid: { color: colors.grid },
            ticks: { color: colors.text }
          },
          x: {
            grid: { color: colors.grid },
            ticks: { color: colors.text }
          }
        }
      }
    })
  }
  
  // Service pie chart
  if (serviceChartRef.value && data.logs?.by_service) {
    const ctx = serviceChartRef.value.getContext('2d')
    if (serviceChart) {
      serviceChart.destroy()
    }
    
    const serviceLabels = Object.keys(data.logs.by_service)
    const serviceData = Object.values(data.logs.by_service)
    
    serviceChart = new Chart(ctx, {
      type: 'doughnut',
      data: {
        labels: serviceLabels,
        datasets: [{
          data: serviceData,
          backgroundColor: [
            '#5e6ad2',
            '#991B1B',
            '#4cb782',
            '#fc7840',
            '#a855f7',
            '#3b82f6'
          ],
          borderWidth: 0
        }]
      },
      options: {
        ...defaultOptions,
        cutout: '60%'
      }
    })
  }
  
  // Level pie chart
  if (levelChartRef.value && data.logs?.by_level) {
    const ctx = levelChartRef.value.getContext('2d')
    if (levelChart) {
      levelChart.destroy()
    }
    
    const levelLabels = Object.keys(data.logs.by_level)
    const levelData = Object.values(data.logs.by_level)
    
    // Map levels to thuglife colors
    const levelColors = {
      error: '#DC2626',
      warn: '#fc7840',
      warning: '#fc7840',
      info: '#3b82f6',
      debug: '#a855f7',
      trace: '#6b6b6b'
    }
    
    const bgColors = levelLabels.map(l => levelColors[l.toLowerCase()] || '#5e6ad2')
    
    levelChart = new Chart(ctx, {
      type: 'doughnut',
      data: {
        labels: levelLabels,
        datasets: [{
          data: levelData,
          backgroundColor: bgColors,
          borderWidth: 0
        }]
      },
      options: {
        ...defaultOptions,
        cutout: '60%'
      }
    })
  }
}

onMounted(() => {
  loadData()
  refreshInterval = setInterval(loadData, 5000)
})

onUnmounted(() => {
  if (refreshInterval) {
    clearInterval(refreshInterval)
  }
  if (volumeChart) volumeChart.destroy()
  if (serviceChart) serviceChart.destroy()
  if (levelChart) levelChart.destroy()
})
</script>

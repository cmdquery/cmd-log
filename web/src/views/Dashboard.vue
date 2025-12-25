<template>
  <div class="dashboard">
    <h2 class="page-title">Dashboard</h2>
    
    <div class="metrics-grid">
      <MetricCard title="Service Status" :value="healthStatus">
        <span class="status-indicator" :class="healthStatusClass">●</span>
        <span>{{ healthStatusText }}</span>
      </MetricCard>
      
      <MetricCard title="Logs Per Second" :value="metrics.logs?.per_second?.toFixed(2) || '-'" />
      
      <MetricCard title="Total Logs (24h)" :value="formatNumber(metrics.logs?.total || 0)" />
      
      <MetricCard title="Recent Errors (1h)" :value="metrics.logs?.recent_errors || 0">
        <span class="error-badge">{{ metrics.logs?.recent_errors || 0 }}</span>
      </MetricCard>
      
      <MetricCard title="Batch Status">
        <div>Current: <span>{{ metrics.batcher?.current_batch_size || '-' }}</span></div>
        <div>Processed: <span>{{ formatNumber(metrics.batcher?.total_processed || 0) }}</span></div>
        <div>Flushes: <span>{{ metrics.batcher?.flush_count || '-' }}</span></div>
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
import { ref, onMounted, onUnmounted, watch } from 'vue'
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
      healthStatusText.value = 'Healthy'
      healthStatusClass.value = 'healthy'
    } else {
      healthStatus.value = 'Unhealthy'
      healthStatusText.value = 'Unhealthy'
      healthStatusClass.value = 'error'
    }
    
    updateCharts(metricsData)
  } catch (error) {
    console.error('Error loading dashboard data:', error)
    healthStatus.value = 'Error'
    healthStatusText.value = 'Error'
    healthStatusClass.value = 'error'
  }
}

const updateCharts = (data) => {
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
          borderColor: 'rgb(75, 192, 192)',
          tension: 0.1
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          y: {
            beginAtZero: true
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
      type: 'pie',
      data: {
        labels: serviceLabels,
        datasets: [{
          data: serviceData,
          backgroundColor: [
            'rgb(255, 99, 132)',
            'rgb(54, 162, 235)',
            'rgb(255, 205, 86)',
            'rgb(75, 192, 192)',
            'rgb(153, 102, 255)',
            'rgb(255, 159, 64)'
          ]
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false
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
    
    levelChart = new Chart(ctx, {
      type: 'pie',
      data: {
        labels: levelLabels,
        datasets: [{
          data: levelData,
          backgroundColor: [
            'rgb(75, 192, 192)',
            'rgb(255, 205, 86)',
            'rgb(255, 99, 132)',
            'rgb(153, 102, 255)',
            'rgb(255, 159, 64)'
          ]
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false
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

<style scoped>
.dashboard {
  padding: 1rem 0;
}

.metrics-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 1.5rem;
  margin-bottom: 2rem;
}

.status-indicator {
  display: inline-block;
  font-size: 1.5rem;
  margin-right: 0.5rem;
}

.status-indicator.healthy {
  color: #27ae60;
}

.status-indicator.error {
  color: #e74c3c;
}

.error-badge {
  display: inline-block;
  background-color: #e74c3c;
  color: white;
  padding: 0.25rem 0.75rem;
  border-radius: 12px;
  font-size: 1.2rem;
  font-weight: 600;
}

.charts-section {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
  gap: 1.5rem;
  margin-top: 2rem;
}

.chart-card {
  background: white;
  padding: 1.5rem;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.chart-card h3 {
  margin-bottom: 1rem;
  color: #2c3e50;
}

.chart-card canvas {
  max-height: 300px;
}

@media (max-width: 768px) {
  .metrics-grid {
    grid-template-columns: 1fr;
  }
  
  .charts-section {
    grid-template-columns: 1fr;
  }
}
</style>


<template>
  <div class="logs-page-fullscreen">
    <!-- Sticky Header with Controls -->
    <div class="logs-header">
      <div class="logs-controls">
        <button @click="loadLogs" class="btn btn--primary btn--sm" title="Refresh (r)">
          ↻ Refresh
        </button>
        
        <div class="filter-bar__group">
          <label class="filter-bar__label">Limit:</label>
          <select v-model="limit" @change="loadLogs" class="filter-bar__select">
            <option value="50">50</option>
            <option value="100">100</option>
            <option value="200">200</option>
            <option value="500">500</option>
          </select>
        </div>
        
        <label class="form-check">
          <input type="checkbox" v-model="autoRefresh" @change="toggleAutoRefresh" class="form-check__input" />
          <span class="form-check__label">Auto-refresh</span>
        </label>
        
        <div class="search-bar flex-1" style="max-width: 300px;">
          <span class="search-bar__icon">🔍</span>
          <input
            ref="searchInput"
            v-model="searchQuery"
            type="text"
            placeholder="Search logs... (Press /)"
            class="search-bar__input"
            @input="handleSearchInput"
          />
        </div>
        
        <div class="badge-group">
          <label v-for="level in logLevels" :key="level" class="form-check">
            <input
              type="checkbox"
              :value="level"
              v-model="selectedLevels"
              @change="applyFilters"
              class="form-check__input"
            />
            <span :class="['badge badge--xs', `badge--${level.toLowerCase()}`]">{{ level }}</span>
          </label>
        </div>
        
        <button
          @click="toggleFollowMode"
          :class="['btn btn--sm', followMode ? 'btn--brand' : 'btn--ghost']"
          :title="followMode ? 'Disable follow mode (f)' : 'Enable follow mode (f)'"
        >
          {{ followMode ? '● Following' : '○ Follow' }}
        </button>
        
        <span v-if="filteredLogs.length !== logs.length" class="badge">
          {{ filteredLogs.length }} / {{ logs.length }}
        </span>
      </div>
    </div>
    
    <!-- Virtual Scrolling Logs Container -->
    <div class="logs-viewer__body" ref="logsContainer" @scroll="handleScroll">
      <div v-if="loading" class="loading-spinner">
        <div class="spinner"></div>
      </div>
      <div v-else-if="filteredLogs.length === 0" class="empty-state">
        <div class="empty-state__icon">📋</div>
        <div class="empty-state__text">
          {{ searchQuery || selectedLevels.length > 0 ? 'No logs match your filters' : 'No logs found' }}
        </div>
      </div>
      <div v-else class="virtual-scroller">
        <div :style="{ height: `${totalHeight}px`, position: 'relative' }">
          <div
            v-for="item in visibleLogs"
            :key="item.log.id"
            :data-index="item.index"
            :style="{
              position: 'absolute',
              top: 0,
              left: 0,
              right: 0,
              height: `${getRowHeight(item.index)}px`,
              transform: `translateY(${(cumulativeHeights?.heights?.[item.index] ?? 0)}px)`,
              display: 'flex',
              flexDirection: 'column'
            }"
          >
            <div
              :class="[
                'log-entry',
                { 'is-selected': selectedIndex === item.index, 'is-expanded': expandedLogId === item.log.id }
              ]"
              @click="toggleLogExpansion(item.log.id)"
              @mouseenter="selectedIndex = item.index"
            >
              <span class="log-entry__time">{{ formatShortTime(item.log.timestamp) }}</span>
              <span :class="['log-entry__level', item.log.level.toLowerCase()]">
                {{ item.log.level }}
              </span>
              <span class="log-entry__service">{{ item.log.service }}</span>
              <span class="log-entry__message">
                {{ truncateMessage(item.log.message, 100) }}
              </span>
              <div v-if="extractMetadataFields(item.log)" class="log-entry__meta">
                <template v-for="(value, key) in extractMetadataFields(item.log)" :key="key">
                  <span v-if="key === 'method'" :class="['badge badge--xs', `method-${value.toLowerCase()}`]">
                    {{ value }}
                  </span>
                  <span v-else-if="key === 'status'" :class="['badge badge--xs', getStatusClass(value)]">
                    {{ value }}
                  </span>
                  <span v-else-if="key === 'path'" class="badge badge--xs">
                    {{ value }}
                  </span>
                  <span v-else-if="key === 'duration'" class="badge badge--xs">
                    {{ value }}
                  </span>
                </template>
              </div>
              <span class="log-entry__chevron" :class="{ 'is-expanded': expandedLogId === item.log.id }">
                ▼
              </span>
            </div>
            
            <!-- Expanded content -->
            <div
              v-if="expandedLogId === item.log.id"
              :ref="(el) => { if (el) expandedContentRefs.set(item.log.id, el); else expandedContentRefs.delete(item.log.id); }"
              class="log-entry__expanded"
            >
              <div v-if="loadingLogId === item.log.id" class="loading-spinner p-4">
                <div class="spinner"></div>
              </div>
              <div v-else-if="expandedLogData && expandedLogData.id === item.log.id">
                <div class="card mb-4">
                  <div class="detail-label">Message</div>
                  <p class="text-body-sm">{{ expandedLogData.message }}</p>
                </div>
                
                <div v-if="expandedLogData.metadata && Object.keys(expandedLogData.metadata).length > 0" class="card mb-4">
                  <div class="detail-label">Metadata</div>
                  <div class="code-block">
                    <div class="code-block__content">
                      <pre>{{ formatMetadata(expandedLogData.metadata) }}</pre>
                    </div>
                  </div>
                </div>
                
                <div class="detail-grid">
                  <div class="detail-item">
                    <div class="detail-label">ID</div>
                    <div class="detail-value code">{{ expandedLogData.id }}</div>
                  </div>
                  <div class="detail-item">
                    <div class="detail-label">Level</div>
                    <div class="detail-value">
                      <span :class="['badge badge--xs', `badge--${expandedLogData.level.toLowerCase()}`]">
                        {{ expandedLogData.level }}
                      </span>
                    </div>
                  </div>
                  <div class="detail-item">
                    <div class="detail-label">Service</div>
                    <div class="detail-value">{{ expandedLogData.service }}</div>
                  </div>
                  <div class="detail-item">
                    <div class="detail-label">Timestamp</div>
                    <div class="detail-value">{{ formatTimestamp(expandedLogData.timestamp) }}</div>
                  </div>
                </div>
              </div>
              <div v-else-if="expandedLogError" class="alert alert--error">
                {{ expandedLogError }}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, watch, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { getRecentLogs, getLogById } from '../services/api'

const router = useRouter()
const logs = ref([])
const loading = ref(false)
const limit = ref(100)
const autoRefresh = ref(true)
const searchQuery = ref('')
const selectedLevels = ref([])
const followMode = ref(false)
const selectedIndex = ref(-1)
const searchInput = ref(null)
const logsContainer = ref(null)
const scrollTop = ref(0)
const containerHeight = ref(0)

const expandedLogId = ref(null)
const expandedLogData = ref(null)
const loadingLogId = ref(null)
const expandedLogError = ref(null)

const expandedHeights = ref(new Map())
const expandedContentRefs = ref(new Map())

let autoRefreshInterval = null
let searchDebounceTimer = null
let resizeObserver = null
let expandedContentResizeObserver = null

const logLevels = ['DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL', 'CRITICAL']

const ROW_HEIGHT = 44
const ESTIMATED_EXPANDED_HEIGHT = 300
const OVERSCAN = 5

const measureExpandedHeight = async (logId) => {
  await nextTick()
  const element = expandedContentRefs.value.get(logId)
  if (element) {
    const height = element.getBoundingClientRect().height
    if (height > 0) {
      expandedHeights.value.set(logId, height)
    }
  }
}

const setupExpandedContentObserver = () => {
  if (expandedContentResizeObserver) {
    expandedContentResizeObserver.disconnect()
  }
  
  expandedContentResizeObserver = new ResizeObserver((entries) => {
    for (const entry of entries) {
      const logId = Array.from(expandedContentRefs.value.entries()).find(
        ([_, el]) => el === entry.target
      )?.[0]
      
      if (logId && entry.contentRect.height > 0) {
        expandedHeights.value.set(logId, entry.contentRect.height)
      }
    }
  })
  
  for (const element of expandedContentRefs.value.values()) {
    if (element) {
      expandedContentResizeObserver.observe(element)
    }
  }
}

const getRowHeight = (index) => {
  const log = filteredLogs.value[index]
  if (!log) return ROW_HEIGHT
  if (expandedLogId.value === log.id) {
    const expandedHeight = expandedHeights.value.get(log.id) || ESTIMATED_EXPANDED_HEIGHT
    return ROW_HEIGHT + expandedHeight
  }
  return ROW_HEIGHT
}

const cumulativeHeights = computed(() => {
  const heights = [0]
  let total = 0
  const logsLength = filteredLogs.value.length
  
  expandedHeights.value.size
  
  for (let i = 0; i < logsLength; i++) {
    heights.push(total)
    const rowHeight = getRowHeight(i)
    if (rowHeight > 0) {
      total += rowHeight
    } else {
      total += ROW_HEIGHT
    }
  }
  
  return { heights, total }
})

const visibleRange = computed(() => {
  if (filteredLogs.value.length === 0) {
    return { start: 0, end: 0 }
  }
  
  const { heights } = cumulativeHeights.value
  if (!heights || heights.length === 0) {
    return { start: 0, end: Math.min(OVERSCAN * 2, filteredLogs.value.length) }
  }
  
  const viewportTop = scrollTop.value
  const viewportBottom = scrollTop.value + containerHeight.value
  
  let start = 0
  let end = filteredLogs.value.length
  
  for (let i = 0; i < heights.length - 1; i++) {
    if (heights[i + 1] > viewportTop) {
      start = Math.max(0, i - OVERSCAN)
      break
    }
  }
  
  for (let i = start; i < heights.length - 1; i++) {
    if (heights[i] > viewportBottom) {
      end = Math.min(filteredLogs.value.length, i + OVERSCAN)
      break
    }
  }
  
  if (expandedLogId.value) {
    const expandedIndex = filteredLogs.value.findIndex(log => log.id === expandedLogId.value)
    if (expandedIndex !== -1) {
      const expandedStart = Math.max(0, expandedIndex - OVERSCAN * 2)
      const expandedEnd = Math.min(filteredLogs.value.length, expandedIndex + OVERSCAN * 2 + 1)
      start = Math.min(start, expandedStart)
      end = Math.max(end, expandedEnd)
    }
  }
  
  start = Math.max(0, Math.min(start, filteredLogs.value.length - 1))
  end = Math.max(start + 1, Math.min(end, filteredLogs.value.length))
  
  return { start, end }
})

const visibleLogs = computed(() => {
  const { start, end } = visibleRange.value
  return filteredLogs.value.slice(start, end).map((log, idx) => ({
    log,
    index: start + idx
  }))
})

const totalHeight = computed(() => cumulativeHeights.value?.total ?? 0)

const handleScroll = (e) => {
  scrollTop.value = e.target.scrollTop
  if (followMode.value && e.target.scrollTop < e.target.scrollHeight - e.target.clientHeight - 10) {
    followMode.value = false
  }
}

const updateContainerHeight = () => {
  if (logsContainer.value) {
    containerHeight.value = logsContainer.value.clientHeight
  }
}

const maintainExpandedItemVisibility = async (logId) => {
  await nextTick()
  if (!logsContainer.value) return
  
  const expandedIndex = filteredLogs.value.findIndex(log => log.id === logId)
  if (expandedIndex === -1) return
  
  const { heights } = cumulativeHeights.value
  if (!heights || expandedIndex >= heights.length) return
  
  const itemTop = heights[expandedIndex] || 0
  const itemHeight = getRowHeight(expandedIndex)
  const itemBottom = itemTop + itemHeight
  
  const viewportTop = scrollTop.value
  const viewportBottom = viewportTop + containerHeight.value
  
  let newScrollTop = scrollTop.value
  
  if (itemTop < viewportTop) {
    newScrollTop = itemTop
  } else if (itemBottom > viewportBottom) {
    newScrollTop = itemBottom - containerHeight.value
  }
  
  if (newScrollTop !== scrollTop.value && !followMode.value) {
    logsContainer.value.scrollTop = newScrollTop
    scrollTop.value = newScrollTop
  }
}

const filteredLogs = computed(() => {
  let result = logs.value

  if (searchQuery.value.trim()) {
    const query = searchQuery.value.toLowerCase().trim()
    result = result.filter(log => {
      const messageMatch = log.message?.toLowerCase().includes(query)
      const serviceMatch = log.service?.toLowerCase().includes(query)
      return messageMatch || serviceMatch
    })
  }

  if (selectedLevels.value.length > 0) {
    result = result.filter(log => 
      selectedLevels.value.includes(log.level.toUpperCase())
    )
  }

  return result
})

watch([filteredLogs, followMode], async () => {
  if (followMode.value && !loading.value) {
    await nextTick()
    if (logsContainer.value) {
      logsContainer.value.scrollTop = logsContainer.value.scrollHeight
    }
  }
}, { deep: true })

watch([filteredLogs, expandedLogId], async () => {
  await nextTick()
  updateContainerHeight()
  setupExpandedContentObserver()
}, { deep: true })

watch(() => expandedContentRefs.value.size, () => {
  nextTick(() => {
    setupExpandedContentObserver()
  })
})

const formatShortTime = (timestamp) => {
  const now = new Date()
  const time = new Date(timestamp)
  const diffMs = now - time
  const diffSecs = Math.floor(diffMs / 1000)
  const diffMins = Math.floor(diffSecs / 60)
  const diffHours = Math.floor(diffMins / 60)
  const diffDays = Math.floor(diffHours / 24)

  if (diffSecs < 60) return 'now'
  if (diffMins < 60) return `${diffMins}m`
  if (diffHours < 24) return `${diffHours}h`
  if (diffDays < 7) return `${diffDays}d`
  return time.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
}

const truncateMessage = (message, maxLength = 150) => {
  if (!message) return ''
  if (message.length <= maxLength) return message
  return message.substring(0, maxLength) + '...'
}

const formatDuration = (ms) => {
  if (typeof ms !== 'number' || isNaN(ms)) {
    const parsed = parseFloat(ms)
    if (isNaN(parsed)) return null
    ms = parsed
  }
  
  if (ms < 1) return `${Math.round(ms * 1000)}μs`
  if (ms < 1000) return `${Math.round(ms)}ms`
  if (ms < 60000) return `${(ms / 1000).toFixed(1)}s`
  const minutes = Math.floor(ms / 60000)
  const seconds = ((ms % 60000) / 1000).toFixed(1)
  return `${minutes}m ${seconds}s`
}

const formatPath = (path, maxLength = 40) => {
  if (!path || typeof path !== 'string') return null
  if (path.length <= maxLength) return path
  
  if (path.length > maxLength) {
    const start = path.substring(0, Math.floor(maxLength * 0.6))
    const end = path.substring(path.length - Math.floor(maxLength * 0.3))
    return `${start}...${end}`
  }
  
  return path
}

const extractMetadataFields = (log) => {
  if (!log.metadata || typeof log.metadata !== 'object') return null
  
  const meta = log.metadata
  const fields = {}
  
  const findField = (possibleNames) => {
    const lowerNames = possibleNames.map(n => n.toLowerCase())
    for (const key in meta) {
      if (lowerNames.includes(key.toLowerCase())) {
        return meta[key]
      }
    }
    return null
  }
  
  const method = findField(['method', 'http_method', 'verb', 'request_method'])
  if (method) fields.method = String(method).toUpperCase()
  
  const path = findField(['path', 'url', 'uri', 'endpoint', 'route'])
  if (path) fields.path = formatPath(String(path))
  
  const status = findField(['status', 'status_code', 'http_status', 'statusCode'])
  if (status !== null && status !== undefined) {
    const statusNum = typeof status === 'number' ? status : parseInt(String(status), 10)
    if (!isNaN(statusNum)) fields.status = statusNum
  }
  
  const duration = findField(['duration', 'response_time', 'latency', 'time_ms', 'timeMs', 'elapsed', 'elapsed_time'])
  if (duration !== null && duration !== undefined) {
    let durationMs = null
    if (typeof duration === 'number') {
      durationMs = duration < 1000 && duration > 0 ? duration * 1000 : duration
    } else if (typeof duration === 'string') {
      const match = duration.match(/^([\d.]+)\s*(ms|s|m|μs)?$/i)
      if (match) {
        const value = parseFloat(match[1])
        const unit = (match[2] || 'ms').toLowerCase()
        if (unit === 's') durationMs = value * 1000
        else if (unit === 'm') durationMs = value * 60000
        else if (unit === 'μs' || unit === 'us') durationMs = value / 1000
        else durationMs = value
      } else {
        durationMs = parseFloat(duration)
      }
    }
    if (durationMs !== null && !isNaN(durationMs) && durationMs >= 0) {
      fields.duration = formatDuration(durationMs)
    }
  }
  
  return Object.keys(fields).length > 0 ? fields : null
}

const getStatusClass = (status) => {
  if (typeof status !== 'number') return ''
  if (status >= 200 && status < 300) return 'badge--success'
  if (status >= 300 && status < 400) return 'badge--info'
  if (status >= 400 && status < 500) return 'badge--warn'
  if (status >= 500) return 'badge--error'
  return ''
}

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

const loadLogDetails = async (logId) => {
  loadingLogId.value = logId
  expandedLogError.value = null
  try {
    const data = await getLogById(logId)
    expandedLogData.value = data
    await nextTick()
    await measureExpandedHeight(logId)
  } catch (err) {
    expandedLogError.value = err.message || 'Failed to load log details'
    expandedLogData.value = null
  } finally {
    loadingLogId.value = null
  }
}

const toggleLogExpansion = async (logId) => {
  if (expandedLogId.value === logId) {
    const previousScrollTop = logsContainer.value?.scrollTop || 0
    expandedLogId.value = null
    expandedLogData.value = null
    expandedLogError.value = null
    expandedHeights.value.delete(logId)
    expandedContentRefs.value.delete(logId)
    
    await nextTick()
    if (logsContainer.value) {
      logsContainer.value.scrollTop = previousScrollTop
    }
  } else {
    const previousExpandedId = expandedLogId.value
    
    expandedLogId.value = logId
    expandedLogData.value = null
    expandedLogError.value = null
    
    if (previousExpandedId) {
      expandedHeights.value.delete(previousExpandedId)
      expandedContentRefs.value.delete(previousExpandedId)
    }
    
    await loadLogDetails(logId)
    await maintainExpandedItemVisibility(logId)
  }
}

const loadLogs = async () => {
  loading.value = true
  try {
    const data = await getRecentLogs(limit.value)
    const newLogs = data.logs || []
    
    const currentExpandedId = expandedLogId.value
    
    if (currentExpandedId) {
      const expandedLogExists = newLogs.some(log => log.id === currentExpandedId)
      if (!expandedLogExists) {
        expandedLogId.value = null
        expandedLogData.value = null
        expandedLogError.value = null
        expandedHeights.value.delete(currentExpandedId)
        expandedContentRefs.value.delete(currentExpandedId)
      }
    }
    
    const newLogIds = new Set(newLogs.map(log => log.id))
    for (const [logId] of expandedHeights.value) {
      if (!newLogIds.has(logId)) {
        expandedHeights.value.delete(logId)
        expandedContentRefs.value.delete(logId)
      }
    }
    
    logs.value = newLogs
    
    await nextTick()
    
    if (currentExpandedId && expandedLogId.value === currentExpandedId) {
      await measureExpandedHeight(currentExpandedId)
      await maintainExpandedItemVisibility(currentExpandedId)
    }
    
    if (followMode.value) {
      await nextTick()
      if (logsContainer.value) {
        logsContainer.value.scrollTop = logsContainer.value.scrollHeight
      }
    }
  } catch (error) {
    logs.value = []
    if (expandedLogId.value) {
      const errorExpandedId = expandedLogId.value
      expandedLogId.value = null
      expandedLogData.value = null
      expandedLogError.value = null
      expandedHeights.value.delete(errorExpandedId)
      expandedContentRefs.value.delete(errorExpandedId)
    }
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
  if (autoRefreshInterval) clearInterval(autoRefreshInterval)
  autoRefreshInterval = setInterval(loadLogs, 5000)
}

const stopAutoRefresh = () => {
  if (autoRefreshInterval) {
    clearInterval(autoRefreshInterval)
    autoRefreshInterval = null
  }
}

const handleSearchInput = () => {
  if (searchDebounceTimer) clearTimeout(searchDebounceTimer)
  searchDebounceTimer = setTimeout(() => {
    selectedIndex.value = -1
  }, 300)
}

const clearSearch = () => {
  searchQuery.value = ''
  selectedIndex.value = -1
}

const applyFilters = () => {
  selectedIndex.value = -1
}

const toggleFollowMode = () => {
  followMode.value = !followMode.value
  if (followMode.value && logsContainer.value) {
    logsContainer.value.scrollTop = logsContainer.value.scrollHeight
  }
}

const handleKeyDown = (e) => {
  if (e.target.tagName === 'INPUT' || e.target.tagName === 'SELECT' || e.target.tagName === 'TEXTAREA') {
    if (e.key === '/' && e.target !== searchInput.value) {
      e.preventDefault()
      searchInput.value?.focus()
    }
    return
  }

  switch (e.key) {
    case '/':
      e.preventDefault()
      searchInput.value?.focus()
      break
    case 'f':
      e.preventDefault()
      toggleFollowMode()
      break
    case 'r':
      e.preventDefault()
      loadLogs()
      break
    case 'Escape':
      e.preventDefault()
      if (searchQuery.value) clearSearch()
      else if (selectedLevels.value.length > 0) selectedLevels.value = []
      break
    case 'ArrowDown':
      e.preventDefault()
      if (filteredLogs.value.length > 0) {
        selectedIndex.value = Math.min(selectedIndex.value + 1, filteredLogs.value.length - 1)
        if (logsContainer.value && selectedIndex.value >= 0) {
          const { heights } = cumulativeHeights.value || { heights: [] }
          const targetScrollTop = heights[selectedIndex.value] || 0
          logsContainer.value.scrollTo({ top: targetScrollTop, behavior: 'smooth' })
        }
      }
      break
    case 'ArrowUp':
      e.preventDefault()
      if (filteredLogs.value.length > 0) {
        selectedIndex.value = Math.max(selectedIndex.value - 1, 0)
        if (logsContainer.value && selectedIndex.value >= 0) {
          const { heights } = cumulativeHeights.value || { heights: [] }
          const targetScrollTop = heights[selectedIndex.value] || 0
          logsContainer.value.scrollTo({ top: targetScrollTop, behavior: 'smooth' })
        }
      }
      break
    case 'Enter':
      e.preventDefault()
      if (selectedIndex.value >= 0 && selectedIndex.value < filteredLogs.value.length) {
        toggleLogExpansion(filteredLogs.value[selectedIndex.value].id)
      }
      break
  }
}

onMounted(() => {
  loadLogs()
  if (autoRefresh.value) startAutoRefresh()
  window.addEventListener('keydown', handleKeyDown)
  updateContainerHeight()
  resizeObserver = new ResizeObserver(() => updateContainerHeight())
  if (logsContainer.value) resizeObserver.observe(logsContainer.value)
  setupExpandedContentObserver()
})

onUnmounted(() => {
  stopAutoRefresh()
  window.removeEventListener('keydown', handleKeyDown)
  if (searchDebounceTimer) clearTimeout(searchDebounceTimer)
  if (resizeObserver) resizeObserver.disconnect()
  if (expandedContentResizeObserver) expandedContentResizeObserver.disconnect()
})
</script>

<style>
.logs-page-fullscreen {
  display: flex;
  flex-direction: column;
  height: calc(100vh - var(--header-height));
  background: var(--bg-level-0);
}

.logs-header {
  position: sticky;
  top: 0;
  z-index: 10;
  background: var(--bg-level-1);
  border-bottom: 1px solid var(--border-primary);
  padding: var(--space-3) var(--space-4);
}

.logs-controls {
  display: flex;
  gap: var(--space-4);
  align-items: center;
  flex-wrap: wrap;
}

.logs-viewer__body {
  flex: 1;
  overflow-y: auto;
  overflow-x: hidden;
  background: var(--bg-level-1);
}

.virtual-scroller {
  position: relative;
  width: 100%;
}

.log-entry {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  padding: var(--space-3) var(--space-4);
  cursor: pointer;
  border-bottom: 1px solid var(--border-primary);
  transition: background-color 0.1s ease;
  font-family: var(--font-mono);
  font-size: var(--text-small);
  height: 44px;
}

.log-entry:hover {
  background-color: var(--bg-level-2);
}

.log-entry.is-selected {
  background-color: var(--color-accent-tint);
  outline: 2px solid var(--color-accent);
  outline-offset: -2px;
}

.log-entry__time {
  color: var(--text-quaternary);
  min-width: 3rem;
  flex-shrink: 0;
  font-size: var(--text-micro);
}

.log-entry__level {
  min-width: 4rem;
  flex-shrink: 0;
  font-weight: var(--weight-semibold);
  text-transform: uppercase;
  font-size: var(--text-micro);
}

.log-entry__level.error { color: var(--color-red); }
.log-entry__level.warn, .log-entry__level.warning { color: var(--color-orange); }
.log-entry__level.info { color: var(--color-blue); }
.log-entry__level.debug { color: var(--color-purple); }
.log-entry__level.trace { color: var(--text-tertiary); }
.log-entry__level.fatal, .log-entry__level.critical { color: var(--color-red); }

.log-entry__service {
  color: var(--text-secondary);
  font-weight: var(--weight-medium);
  min-width: 8rem;
  flex-shrink: 0;
}

.log-entry__message {
  flex: 1;
  color: var(--text-secondary);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  min-width: 0;
}

.log-entry__meta {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  flex-shrink: 0;
  margin-left: auto;
}

.log-entry__chevron {
  color: var(--text-quaternary);
  font-size: var(--text-micro);
  transition: transform 0.2s ease;
  flex-shrink: 0;
}

.log-entry__chevron.is-expanded {
  transform: rotate(180deg);
  color: var(--color-accent);
}

.log-entry__expanded {
  background-color: var(--bg-level-2);
  border-bottom: 1px solid var(--border-primary);
  padding: var(--space-4);
  animation: slideDown 0.2s ease;
}

.method-get { background-color: var(--color-blue-bg); color: var(--color-blue-text); }
.method-post { background-color: var(--color-green-bg); color: var(--color-green-text); }
.method-put { background-color: var(--color-orange-bg); color: var(--color-orange-text); }
.method-patch { background-color: var(--color-purple-bg); color: var(--color-purple-text); }
.method-delete { background-color: var(--color-red-bg); color: var(--color-red-text); }
</style>

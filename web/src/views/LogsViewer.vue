<template>
  <div class="logs-page-fullscreen">
    <!-- Sticky Header with Controls -->
    <div class="logs-header-sticky">
      <div class="logs-controls">
        <button @click="loadLogs" class="btn btn-primary" title="Refresh (r)">Refresh</button>
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
        <div class="search-container">
          <input
            ref="searchInput"
            v-model="searchQuery"
            type="text"
            placeholder="Search logs... (Press / to focus)"
            class="search-input"
            @input="handleSearchInput"
          />
          <span v-if="searchQuery" class="search-clear" @click="clearSearch" title="Clear search">×</span>
        </div>
        <div class="level-filters">
          <label v-for="level in logLevels" :key="level" class="level-filter-checkbox">
            <input
              type="checkbox"
              :value="level"
              v-model="selectedLevels"
              @change="applyFilters"
            />
            <span :class="['level-filter-label', `level-${level.toLowerCase()}`]">{{ level }}</span>
          </label>
        </div>
        <button
          @click="toggleFollowMode"
          :class="['btn', 'btn-follow', { 'btn-follow-active': followMode }]"
          :title="followMode ? 'Disable follow mode (f)' : 'Enable follow mode (f)'"
        >
          {{ followMode ? '● Follow' : '○ Follow' }}
        </button>
        <span v-if="filteredLogs.length !== logs.length" class="filter-badge">
          {{ filteredLogs.length }} / {{ logs.length }}
        </span>
      </div>
    </div>
    
    <!-- Virtual Scrolling Logs Container -->
    <div class="logs-list-container-fullscreen" ref="logsContainer" @scroll="handleScroll">
      <div v-if="loading" class="loading-state">
        Loading logs...
      </div>
      <div v-else-if="filteredLogs.length === 0" class="empty-state">
        {{ searchQuery || selectedLevels.length > 0 ? 'No logs match your filters' : 'No logs found' }}
      </div>
      <div
        v-else
        class="virtual-scroller-parent"
      >
        <div
          :style="{ height: `${totalHeight}px`, position: 'relative' }"
        >
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
                'log-row-compact',
                `level-${item.log.level.toLowerCase()}`,
                { 'log-row-selected': selectedIndex === item.index, 'log-row-expanded': expandedLogId === item.log.id }
              ]"
              @click="toggleLogExpansion(item.log.id)"
              @mouseenter="selectedIndex = item.index"
            >
              <div class="log-row-indicator" :class="`level-${item.log.level.toLowerCase()}`"></div>
              <span :class="['level-badge-compact', `level-${item.log.level.toLowerCase()}`]">
                {{ item.log.level }}
              </span>
              <span class="log-timestamp-compact">{{ formatShortTime(item.log.timestamp) }}</span>
              <span class="log-service-compact">{{ item.log.service }}</span>
              <span class="log-message-compact" :title="item.log.message">
                {{ truncateMessage(item.log.message, 100) }}
              </span>
              <div v-if="extractMetadataFields(item.log)" class="log-row-metadata">
                <template v-for="(value, key) in extractMetadataFields(item.log)" :key="key">
                  <span
                    v-if="key === 'method'"
                    :class="['metadata-badge', 'metadata-method', `method-${value.toLowerCase()}`]"
                    :title="`HTTP Method: ${value}`"
                  >
                    {{ value }}
                  </span>
                  <span
                    v-else-if="key === 'status'"
                    :class="['metadata-badge', 'metadata-status', getStatusClass(value)]"
                    :title="`Status Code: ${value}`"
                  >
                    {{ value }}
                  </span>
                  <span
                    v-else-if="key === 'path'"
                    class="metadata-badge metadata-path"
                    :title="`Path: ${value}`"
                  >
                    {{ value }}
                  </span>
                  <span
                    v-else-if="key === 'duration'"
                    class="metadata-badge metadata-duration"
                    :title="`Duration: ${value}`"
                  >
                    {{ value }}
                  </span>
                  <span
                    v-else-if="key === 'requestId'"
                    class="metadata-badge metadata-request-id"
                    :title="`Request ID: ${value}`"
                  >
                    ID: {{ value }}
                  </span>
                  <span
                    v-else-if="key === 'userId'"
                    class="metadata-badge metadata-user-id"
                    :title="`User ID: ${value}`"
                  >
                    User: {{ value }}
                  </span>
                </template>
              </div>
              <span class="log-row-chevron" :class="{ 'expanded': expandedLogId === item.log.id }">
                <svg width="12" height="12" viewBox="0 0 12 12" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path d="M3 4.5L6 7.5L9 4.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
              </span>
            </div>
            <!-- Expanded content -->
            <div
              v-if="expandedLogId === item.log.id"
              :ref="(el) => { if (el) expandedContentRefs.set(item.log.id, el); else expandedContentRefs.delete(item.log.id); }"
              class="log-row-expanded-content"
            >
              <div v-if="loadingLogId === item.log.id" class="log-expanded-loading">
                Loading log details...
              </div>
              <div v-else-if="expandedLogData && expandedLogData.id === item.log.id" class="log-expanded-details">
                <div class="log-expanded-section">
                  <h3 class="log-expanded-section-title">Message</h3>
                  <p class="log-expanded-message">{{ expandedLogData.message }}</p>
                </div>
                <div v-if="expandedLogData.metadata && Object.keys(expandedLogData.metadata).length > 0" class="log-expanded-section">
                  <h3 class="log-expanded-section-title">Metadata</h3>
                  <pre class="log-expanded-metadata">{{ formatMetadata(expandedLogData.metadata) }}</pre>
                </div>
                <div class="log-expanded-section">
                  <h3 class="log-expanded-section-title">Details</h3>
                  <div class="log-expanded-details-grid">
                    <div class="log-expanded-detail-item">
                      <span class="log-expanded-detail-label">ID:</span>
                      <span class="log-expanded-detail-value">{{ expandedLogData.id }}</span>
                    </div>
                    <div class="log-expanded-detail-item">
                      <span class="log-expanded-detail-label">Level:</span>
                      <span :class="['log-expanded-detail-value', `level-${expandedLogData.level.toLowerCase()}`]">
                        {{ expandedLogData.level }}
                      </span>
                    </div>
                    <div class="log-expanded-detail-item">
                      <span class="log-expanded-detail-label">Service:</span>
                      <span class="log-expanded-detail-value">{{ expandedLogData.service }}</span>
                    </div>
                    <div class="log-expanded-detail-item">
                      <span class="log-expanded-detail-label">Timestamp:</span>
                      <span class="log-expanded-detail-value">{{ formatTimestamp(expandedLogData.timestamp) }}</span>
                    </div>
                  </div>
                </div>
              </div>
              <div v-else-if="expandedLogError" class="log-expanded-error">
                Error loading log: {{ expandedLogError }}
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

// Accordion state
const expandedLogId = ref(null)
const expandedLogData = ref(null)
const loadingLogId = ref(null)
const expandedLogError = ref(null)

// Track measured heights of expanded content (keyed by log ID)
const expandedHeights = ref(new Map())
const expandedContentRefs = ref(new Map()) // Store refs to expanded content elements

let autoRefreshInterval = null
let searchDebounceTimer = null
let resizeObserver = null
let expandedContentResizeObserver = null

const logLevels = ['DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL', 'CRITICAL']

const ROW_HEIGHT = 38
const ESTIMATED_EXPANDED_HEIGHT = 300 // Fallback during loading
const OVERSCAN = 5

// Measure the actual height of expanded content
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

// Set up ResizeObserver for expanded content
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
  
  // Observe all currently expanded content elements
  for (const element of expandedContentRefs.value.values()) {
    if (element) {
      expandedContentResizeObserver.observe(element)
    }
  }
}

// Calculate row heights accounting for expanded content
const getRowHeight = (index) => {
  const log = filteredLogs.value[index]
  if (!log) return ROW_HEIGHT
  if (expandedLogId.value === log.id) {
    // Use measured height if available, otherwise use estimated height
    const expandedHeight = expandedHeights.value.get(log.id) || ESTIMATED_EXPANDED_HEIGHT
    return ROW_HEIGHT + expandedHeight
  }
  return ROW_HEIGHT
}

// Calculate cumulative heights for virtual scrolling
// This depends on filteredLogs, expandedLogId, and expandedHeights
const cumulativeHeights = computed(() => {
  const heights = [0] // Start with 0 for first row
  let total = 0
  const logsLength = filteredLogs.value.length
  
  // Access expandedHeights to create dependency
  expandedHeights.value.size // Trigger reactivity
  
  for (let i = 0; i < logsLength; i++) {
    heights.push(total)
    const rowHeight = getRowHeight(i)
    // Defensive check to prevent negative or invalid heights
    if (rowHeight > 0) {
      total += rowHeight
    } else {
      total += ROW_HEIGHT // Fallback to default height
    }
  }
  
  return { heights, total }
})

// Virtual scrolling implementation with variable heights
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
  
  // Find start index
  for (let i = 0; i < heights.length - 1; i++) {
    if (heights[i + 1] > viewportTop) {
      start = Math.max(0, i - OVERSCAN)
      break
    }
  }
  
  // Find end index
  for (let i = start; i < heights.length - 1; i++) {
    if (heights[i] > viewportBottom) {
      end = Math.min(filteredLogs.value.length, i + OVERSCAN)
      break
    }
  }
  
  // Ensure expanded item is always in visible range
  if (expandedLogId.value) {
    const expandedIndex = filteredLogs.value.findIndex(log => log.id === expandedLogId.value)
    if (expandedIndex !== -1) {
      // Expand range to include expanded item with padding
      const expandedStart = Math.max(0, expandedIndex - OVERSCAN * 2)
      const expandedEnd = Math.min(filteredLogs.value.length, expandedIndex + OVERSCAN * 2 + 1)
      start = Math.min(start, expandedStart)
      end = Math.max(end, expandedEnd)
    }
  }
  
  // Bounds checking
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
  // Disable follow mode if user scrolls up
  if (followMode.value && e.target.scrollTop < e.target.scrollHeight - e.target.clientHeight - 10) {
    followMode.value = false
  }
}

const updateContainerHeight = () => {
  if (logsContainer.value) {
    containerHeight.value = logsContainer.value.clientHeight
  }
}

// Maintain expanded item visibility by adjusting scroll position
const maintainExpandedItemVisibility = async (logId) => {
  await nextTick()
  if (!logsContainer.value) return
  
  // Find the index of the expanded log
  const expandedIndex = filteredLogs.value.findIndex(log => log.id === logId)
  if (expandedIndex === -1) return
  
  const { heights } = cumulativeHeights.value
  if (!heights || expandedIndex >= heights.length) return
  
  // Get the position of the expanded item
  const itemTop = heights[expandedIndex] || 0
  const itemHeight = getRowHeight(expandedIndex)
  const itemBottom = itemTop + itemHeight
  
  // Get viewport bounds
  const viewportTop = scrollTop.value
  const viewportBottom = viewportTop + containerHeight.value
  
  // Check if item is fully visible
  let newScrollTop = scrollTop.value
  
  if (itemTop < viewportTop) {
    // Item is above viewport - scroll to show it at top
    newScrollTop = itemTop
  } else if (itemBottom > viewportBottom) {
    // Item extends below viewport - scroll to show it fully
    newScrollTop = itemBottom - containerHeight.value
  }
  
  // Only adjust if needed and not in follow mode
  if (newScrollTop !== scrollTop.value && !followMode.value) {
    logsContainer.value.scrollTop = newScrollTop
    scrollTop.value = newScrollTop
  }
}

// Filtered logs based on search and level filters
const filteredLogs = computed(() => {
  let result = logs.value

  // Filter by search query
  if (searchQuery.value.trim()) {
    const query = searchQuery.value.toLowerCase().trim()
    result = result.filter(log => {
      const messageMatch = log.message?.toLowerCase().includes(query)
      const serviceMatch = log.service?.toLowerCase().includes(query)
      return messageMatch || serviceMatch
    })
  }

  // Filter by selected levels
  if (selectedLevels.value.length > 0) {
    result = result.filter(log => 
      selectedLevels.value.includes(log.level.toUpperCase())
    )
  }

  return result
})

// Watch filtered logs and scroll to bottom if follow mode is enabled
watch([filteredLogs, followMode], async () => {
  if (followMode.value && !loading.value) {
    await nextTick()
    if (logsContainer.value) {
      logsContainer.value.scrollTop = logsContainer.value.scrollHeight
    }
  }
}, { deep: true })

// Watch for changes in logs or expanded state to ensure proper recalculation
watch([filteredLogs, expandedLogId], async () => {
  // Force recalculation of container height and positions
  await nextTick()
  updateContainerHeight()
  // Set up observer for newly expanded content
  setupExpandedContentObserver()
}, { deep: true })

// Watch expanded content refs to set up ResizeObserver
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

  if (diffSecs < 60) {
    return 'now'
  } else if (diffMins < 60) {
    return `${diffMins}m`
  } else if (diffHours < 24) {
    return `${diffHours}h`
  } else if (diffDays < 7) {
    return `${diffDays}d`
  } else {
    return time.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
  }
}

const truncateMessage = (message, maxLength = 150) => {
  if (!message) return ''
  if (message.length <= maxLength) return message
  return message.substring(0, maxLength) + '...'
}

const hasMetadata = (log) => {
  return log.metadata && Object.keys(log.metadata).length > 0
}

// Format duration in milliseconds to human-readable format
const formatDuration = (ms) => {
  if (typeof ms !== 'number' || isNaN(ms)) {
    // Try to parse if it's a string
    const parsed = parseFloat(ms)
    if (isNaN(parsed)) return null
    ms = parsed
  }
  
  if (ms < 1) {
    return `${Math.round(ms * 1000)}μs`
  } else if (ms < 1000) {
    return `${Math.round(ms)}ms`
  } else if (ms < 60000) {
    return `${(ms / 1000).toFixed(1)}s`
  } else {
    const minutes = Math.floor(ms / 60000)
    const seconds = ((ms % 60000) / 1000).toFixed(1)
    return `${minutes}m ${seconds}s`
  }
}

// Format path/URL for display with intelligent truncation
const formatPath = (path, maxLength = 40) => {
  if (!path || typeof path !== 'string') return null
  if (path.length <= maxLength) return path
  
  // Try to keep the important parts (start and end)
  if (path.length > maxLength) {
    const start = path.substring(0, Math.floor(maxLength * 0.6))
    const end = path.substring(path.length - Math.floor(maxLength * 0.3))
    return `${start}...${end}`
  }
  
  return path
}

// Extract and format common metadata fields with smart field name matching
const extractMetadataFields = (log) => {
  if (!log.metadata || typeof log.metadata !== 'object') return null
  
  const meta = log.metadata
  const fields = {}
  
  // Helper to find field by multiple possible names (case-insensitive)
  const findField = (possibleNames) => {
    const lowerNames = possibleNames.map(n => n.toLowerCase())
    for (const key in meta) {
      if (lowerNames.includes(key.toLowerCase())) {
        return meta[key]
      }
    }
    return null
  }
  
  // Extract HTTP method
  const method = findField(['method', 'http_method', 'verb', 'request_method'])
  if (method) {
    fields.method = String(method).toUpperCase()
  }
  
  // Extract path/URL
  const path = findField(['path', 'url', 'uri', 'endpoint', 'route'])
  if (path) {
    fields.path = formatPath(String(path))
  }
  
  // Extract status code
  const status = findField(['status', 'status_code', 'http_status', 'statusCode'])
  if (status !== null && status !== undefined) {
    const statusNum = typeof status === 'number' ? status : parseInt(String(status), 10)
    if (!isNaN(statusNum)) {
      fields.status = statusNum
    }
  }
  
  // Extract duration (could be in ms, seconds, or as a string)
  const duration = findField(['duration', 'response_time', 'latency', 'time_ms', 'timeMs', 'elapsed', 'elapsed_time'])
  if (duration !== null && duration !== undefined) {
    let durationMs = null
    if (typeof duration === 'number') {
      // If it's a small number (< 1000), assume seconds, otherwise assume ms
      durationMs = duration < 1000 && duration > 0 ? duration * 1000 : duration
    } else if (typeof duration === 'string') {
      // Try to parse strings like "123ms", "1.2s", etc.
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
  
  // Extract request ID
  const requestId = findField(['request_id', 'req_id', 'trace_id', 'correlation_id', 'requestId', 'traceId'])
  if (requestId) {
    const idStr = String(requestId)
    fields.requestId = idStr.length > 12 ? idStr.substring(0, 12) + '...' : idStr
  }
  
  // Extract user ID
  const userId = findField(['user_id', 'uid', 'userId'])
  if (userId) {
    fields.userId = String(userId)
  }
  
  // Return null if no meaningful fields found
  return Object.keys(fields).length > 0 ? fields : null
}

// Get CSS class for status code based on HTTP status range
const getStatusClass = (status) => {
  if (typeof status !== 'number') return 'status-unknown'
  if (status >= 200 && status < 300) return 'status-2xx'
  if (status >= 300 && status < 400) return 'status-3xx'
  if (status >= 400 && status < 500) return 'status-4xx'
  if (status >= 500) return 'status-5xx'
  return 'status-unknown'
}

// Format timestamp for expanded view
const formatTimestamp = (timestamp) => {
  return new Date(timestamp).toLocaleString()
}

// Format metadata for display
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

// Load log details asynchronously
const loadLogDetails = async (logId) => {
  loadingLogId.value = logId
  expandedLogError.value = null
  try {
    const data = await getLogById(logId)
    expandedLogData.value = data
    // Measure height after data loads
    await nextTick()
    await measureExpandedHeight(logId)
  } catch (err) {
    console.error('Error loading log details:', err)
    expandedLogError.value = err.message || 'Failed to load log details'
    expandedLogData.value = null
  } finally {
    loadingLogId.value = null
  }
}

// Toggle log expansion
const toggleLogExpansion = async (logId) => {
  if (expandedLogId.value === logId) {
    // Collapse if clicking the same row
    const previousScrollTop = logsContainer.value?.scrollTop || 0
    expandedLogId.value = null
    expandedLogData.value = null
    expandedLogError.value = null
    expandedHeights.value.delete(logId)
    expandedContentRefs.value.delete(logId)
    
    // Maintain scroll position after collapse
    await nextTick()
    if (logsContainer.value) {
      logsContainer.value.scrollTop = previousScrollTop
    }
  } else {
    // Store previous expanded log ID for cleanup
    const previousExpandedId = expandedLogId.value
    
    // Expand new row
    expandedLogId.value = logId
    expandedLogData.value = null
    expandedLogError.value = null
    
    // Clear previous expanded height if exists
    if (previousExpandedId) {
      expandedHeights.value.delete(previousExpandedId)
      expandedContentRefs.value.delete(previousExpandedId)
    }
    
    await loadLogDetails(logId)
    
    // Adjust scroll position to keep expanded item visible
    // Height is already measured in loadLogDetails
    await maintainExpandedItemVisibility(logId)
  }
}

const navigateToLog = (id) => {
  router.push(`/admin/logs/${id}`)
}

const loadLogs = async () => {
  loading.value = true
  try {
    const data = await getRecentLogs(limit.value)
    const newLogs = data.logs || []
    
    // Store current expanded state
    const currentExpandedId = expandedLogId.value
    
    // Check if expanded log still exists in new logs
    if (currentExpandedId) {
      const expandedLogExists = newLogs.some(log => log.id === currentExpandedId)
      if (!expandedLogExists) {
        // Collapse if expanded log no longer exists
        expandedLogId.value = null
        expandedLogData.value = null
        expandedLogError.value = null
        expandedHeights.value.delete(currentExpandedId)
        expandedContentRefs.value.delete(currentExpandedId)
      }
    }
    
    // Clean up heights for logs that no longer exist
    const newLogIds = new Set(newLogs.map(log => log.id))
    for (const [logId] of expandedHeights.value) {
      if (!newLogIds.has(logId)) {
        expandedHeights.value.delete(logId)
        expandedContentRefs.value.delete(logId)
      }
    }
    
    logs.value = newLogs
    
    // Wait for DOM to update before recalculating positions
    await nextTick()
    
    // Re-measure expanded content if it still exists
    if (currentExpandedId && expandedLogId.value === currentExpandedId) {
      await measureExpandedHeight(currentExpandedId)
      // Maintain visibility of expanded item
      await maintainExpandedItemVisibility(currentExpandedId)
    }
    
    // If follow mode is on, scroll to bottom after loading
    if (followMode.value) {
      await nextTick()
      if (logsContainer.value) {
        logsContainer.value.scrollTop = logsContainer.value.scrollHeight
      }
    }
  } catch (error) {
    console.error('Error loading logs:', error)
    logs.value = []
    // Collapse expanded log on error
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

const handleSearchInput = () => {
  if (searchDebounceTimer) {
    clearTimeout(searchDebounceTimer)
  }
  searchDebounceTimer = setTimeout(() => {
    // Filtering is handled by computed property
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

// Keyboard shortcuts
const handleKeyDown = (e) => {
  // Don't handle shortcuts if user is typing in an input
  if (e.target.tagName === 'INPUT' || e.target.tagName === 'SELECT' || e.target.tagName === 'TEXTAREA') {
    // Special case: allow '/' to focus search even when in input
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
      if (searchQuery.value) {
        clearSearch()
      } else if (selectedLevels.value.length > 0) {
        selectedLevels.value = []
      }
      break
    case 'ArrowDown':
      e.preventDefault()
      if (filteredLogs.value.length > 0) {
        selectedIndex.value = Math.min(selectedIndex.value + 1, filteredLogs.value.length - 1)
        // Scroll selected row into view
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
        // Scroll selected row into view
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
  if (autoRefresh.value) {
    startAutoRefresh()
  }
  window.addEventListener('keydown', handleKeyDown)
  updateContainerHeight()
  // Update container height on resize
  resizeObserver = new ResizeObserver(() => {
    updateContainerHeight()
  })
  if (logsContainer.value) {
    resizeObserver.observe(logsContainer.value)
  }
  // Set up observer for expanded content
  setupExpandedContentObserver()
})

onUnmounted(() => {
  stopAutoRefresh()
  window.removeEventListener('keydown', handleKeyDown)
  if (searchDebounceTimer) {
    clearTimeout(searchDebounceTimer)
  }
  if (resizeObserver) {
    resizeObserver.disconnect()
  }
  if (expandedContentResizeObserver) {
    expandedContentResizeObserver.disconnect()
  }
})
</script>

<style scoped>
.logs-page-fullscreen {
  display: flex;
  flex-direction: column;
  height: 100%;
  background: #f5f5f5;
}

.logs-header-sticky {
  position: sticky;
  top: 0;
  z-index: 10;
  background: white;
  border-bottom: 1px solid #e0e0e0;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.logs-controls {
  display: flex;
  gap: 1rem;
  align-items: center;
  padding: 0.75rem 1rem;
  flex-wrap: wrap;
}

.logs-controls label {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.875rem;
}

.logs-controls select {
  padding: 0.4rem 0.6rem;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 0.875rem;
}

.search-container {
  position: relative;
  flex: 1;
  min-width: 200px;
  max-width: 400px;
}

.search-input {
  width: 100%;
  padding: 0.5rem 2rem 0.5rem 0.75rem;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 0.875rem;
}

.search-input:focus {
  outline: none;
  border-color: #007bff;
  box-shadow: 0 0 0 2px rgba(0, 123, 255, 0.1);
}

.search-clear {
  position: absolute;
  right: 0.5rem;
  top: 50%;
  transform: translateY(-50%);
  cursor: pointer;
  font-size: 1.5rem;
  color: #666;
  line-height: 1;
  padding: 0 0.25rem;
}

.search-clear:hover {
  color: #333;
}

.level-filters {
  display: flex;
  gap: 0.5rem;
  align-items: center;
}

.level-filter-checkbox {
  display: flex;
  align-items: center;
  gap: 0.25rem;
  cursor: pointer;
  font-size: 0.75rem;
}

.level-filter-label {
  padding: 0.2rem 0.4rem;
  border-radius: 3px;
  font-weight: 600;
  text-transform: uppercase;
  font-size: 0.7rem;
}

.level-filter-label.level-debug {
  background-color: #e2e3e5;
  color: #383d41;
}

.level-filter-label.level-info {
  background-color: #d1ecf1;
  color: #0c5460;
}

.level-filter-label.level-warn,
.level-filter-label.level-warning {
  background-color: #fff3cd;
  color: #856404;
}

.level-filter-label.level-error {
  background-color: #f8d7da;
  color: #721c24;
}

.level-filter-label.level-fatal,
.level-filter-label.level-critical {
  background-color: #721c24;
  color: #fff;
}

.btn {
  padding: 0.5rem 1rem;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-weight: 500;
  font-size: 0.875rem;
  transition: background-color 0.15s ease;
}

.btn-primary {
  background-color: #007bff;
  color: white;
}

.btn-primary:hover {
  background-color: #0056b3;
}

.btn-follow {
  background-color: #6c757d;
  color: white;
}

.btn-follow:hover {
  background-color: #5a6268;
}

.btn-follow-active {
  background-color: #28a745;
}

.btn-follow-active:hover {
  background-color: #218838;
}

.filter-badge {
  padding: 0.25rem 0.5rem;
  background-color: #e9ecef;
  border-radius: 12px;
  font-size: 0.75rem;
  font-weight: 600;
  color: #495057;
}

.logs-list-container-fullscreen {
  flex: 1;
  background: white;
  position: relative;
  overflow-y: auto;
  overflow-x: hidden;
}

.virtual-scroller-parent {
  position: relative;
  width: 100%;
}

.loading-state,
.empty-state {
  padding: 2rem;
  text-align: center;
  color: #666;
  font-family: 'Monaco', 'Menlo', 'Consolas', 'Courier New', monospace;
}

.log-row-compact {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.5rem 1rem;
  cursor: pointer;
  border-bottom: 1px solid #e9ecef;
  transition: background-color 0.1s ease;
  font-family: 'Monaco', 'Menlo', 'Consolas', 'Courier New', monospace;
  font-size: 0.8125rem;
  line-height: 1.4;
  height: 38px;
  position: relative;
}

.log-row-metadata {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-shrink: 0;
  margin-left: auto;
}

.log-row-compact:hover {
  background-color: #f8f9fa;
}

.log-row-compact.log-row-selected {
  background-color: #e3f2fd;
  outline: 2px solid #2196f3;
  outline-offset: -2px;
}

.log-row-indicator {
  width: 3px;
  height: 100%;
  flex-shrink: 0;
  position: absolute;
  left: 0;
  top: 0;
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

.level-badge-compact {
  display: inline-flex;
  align-items: center;
  padding: 0.15rem 0.4rem;
  border-radius: 3px;
  font-size: 0.7rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.3px;
  flex-shrink: 0;
  min-width: 50px;
  justify-content: center;
}

.level-badge-compact.level-info {
  background-color: #d1ecf1;
  color: #0c5460;
}

.level-badge-compact.level-warn,
.level-badge-compact.level-warning {
  background-color: #fff3cd;
  color: #856404;
}

.level-badge-compact.level-error {
  background-color: #f8d7da;
  color: #721c24;
}

.level-badge-compact.level-fatal,
.level-badge-compact.level-critical {
  background-color: #721c24;
  color: #fff;
}

.level-badge-compact.level-debug {
  background-color: #e2e3e5;
  color: #383d41;
}

.log-timestamp-compact {
  color: #6c757d;
  flex-shrink: 0;
  min-width: 40px;
  font-size: 0.75rem;
}

.log-service-compact {
  color: #495057;
  font-weight: 500;
  flex-shrink: 0;
  min-width: 120px;
  font-size: 0.8125rem;
}

.log-message-compact {
  flex: 1;
  color: #2c3e50;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  min-width: 0;
  max-width: 200px;
}

.log-row-chevron {
  display: flex;
  align-items: center;
  justify-content: center;
  color: #6c757d;
  flex-shrink: 0;
  transition: transform 0.2s ease, color 0.2s ease;
  margin-left: 0.5rem;
}

.log-row-chevron.expanded {
  transform: rotate(180deg);
  color: #007bff;
}

.log-row-chevron svg {
  width: 12px;
  height: 12px;
}

.log-row-expanded-content {
  background-color: #f8f9fa;
  border-bottom: 1px solid #e9ecef;
  padding: 1rem;
  animation: slideDown 0.2s ease;
  flex: 1;
  overflow: visible;
}

@keyframes slideDown {
  from {
    opacity: 0;
    max-height: 0;
  }
  to {
    opacity: 1;
    max-height: none;
  }
}

.log-expanded-loading,
.log-expanded-error {
  padding: 1rem;
  text-align: center;
  color: #666;
  font-size: 0.875rem;
}

.log-expanded-error {
  color: #721c24;
  background-color: #f8d7da;
  border-radius: 4px;
}

.log-expanded-details {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.log-expanded-section {
  background: white;
  border-radius: 4px;
  padding: 1rem;
  border: 1px solid #dee2e6;
}

.log-expanded-section-title {
  margin: 0 0 0.75rem 0;
  font-size: 0.875rem;
  font-weight: 600;
  color: #495057;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  border-bottom: 2px solid #dee2e6;
  padding-bottom: 0.5rem;
}

.log-expanded-message {
  margin: 0;
  color: #2c3e50;
  font-size: 0.875rem;
  line-height: 1.5;
  word-wrap: break-word;
}

.log-expanded-metadata {
  margin: 0;
  padding: 0.75rem;
  background-color: #f8f9fa;
  border: 1px solid #dee2e6;
  border-radius: 4px;
  font-family: 'Monaco', 'Menlo', 'Consolas', 'Courier New', monospace;
  font-size: 0.75rem;
  line-height: 1.5;
  color: #2c3e50;
  white-space: pre-wrap;
  word-wrap: break-word;
  overflow-x: auto;
  overflow-y: visible;
}

.log-expanded-details-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 0.75rem;
}

.log-expanded-detail-item {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.log-expanded-detail-label {
  font-size: 0.75rem;
  color: #666;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  font-weight: 600;
}

.log-expanded-detail-value {
  font-size: 0.875rem;
  color: #2c3e50;
  font-weight: 500;
}

.log-expanded-detail-value.level-error {
  color: #721c24;
}

.log-expanded-detail-value.level-warn,
.log-expanded-detail-value.level-warning {
  color: #856404;
}

.log-expanded-detail-value.level-info {
  color: #1976d2;
}

.log-metadata-indicator-compact {
  display: flex;
  align-items: center;
  color: #6c757d;
  flex-shrink: 0;
  margin-left: auto;
}

.log-metadata-indicator-compact svg {
  width: 12px;
  height: 12px;
}

/* Metadata badges styling */
.metadata-badge {
  display: inline-flex;
  align-items: center;
  padding: 0.2rem 0.5rem;
  border-radius: 3px;
  font-size: 0.7rem;
  font-weight: 500;
  white-space: nowrap;
  flex-shrink: 0;
  line-height: 1.2;
}

/* HTTP Method badges */
.metadata-method {
  text-transform: uppercase;
  letter-spacing: 0.3px;
}

.method-get {
  background-color: #e3f2fd;
  color: #1976d2;
}

.method-post {
  background-color: #e8f5e9;
  color: #388e3c;
}

.method-put {
  background-color: #fff3e0;
  color: #f57c00;
}

.method-patch {
  background-color: #f3e5f5;
  color: #7b1fa2;
}

.method-delete {
  background-color: #ffebee;
  color: #d32f2f;
}

.method-head,
.method-options {
  background-color: #f5f5f5;
  color: #616161;
}

/* Status code badges */
.metadata-status {
  font-weight: 600;
  font-family: 'Monaco', 'Menlo', 'Consolas', 'Courier New', monospace;
}

.status-2xx {
  background-color: #e8f5e9;
  color: #2e7d32;
}

.status-3xx {
  background-color: #e3f2fd;
  color: #1976d2;
}

.status-4xx {
  background-color: #fff3cd;
  color: #856404;
}

.status-5xx {
  background-color: #f8d7da;
  color: #721c24;
}

.status-unknown {
  background-color: #e9ecef;
  color: #495057;
}

/* Path badge */
.metadata-path {
  background-color: #f8f9fa;
  color: #495057;
  font-family: 'Monaco', 'Menlo', 'Consolas', 'Courier New', monospace;
  max-width: 200px;
  overflow: hidden;
  text-overflow: ellipsis;
}

/* Duration badge */
.metadata-duration {
  background-color: #e9ecef;
  color: #495057;
  font-family: 'Monaco', 'Menlo', 'Consolas', 'Courier New', monospace;
}

/* Request ID badge */
.metadata-request-id {
  background-color: #f0f0f0;
  color: #666;
  font-family: 'Monaco', 'Menlo', 'Consolas', 'Courier New', monospace;
  font-size: 0.65rem;
}

/* User ID badge */
.metadata-user-id {
  background-color: #f0f0f0;
  color: #666;
  font-family: 'Monaco', 'Menlo', 'Consolas', 'Courier New', monospace;
  font-size: 0.65rem;
}

/* Subtle background tinting for error/warn rows */
.log-row-compact.level-error {
  background-color: rgba(220, 53, 69, 0.03);
}

.log-row-compact.level-error:hover {
  background-color: rgba(220, 53, 69, 0.08);
}

.log-row-compact.level-warn,
.log-row-compact.level-warning {
  background-color: rgba(255, 193, 7, 0.03);
}

.log-row-compact.level-warn:hover,
.log-row-compact.level-warning:hover {
  background-color: rgba(255, 193, 7, 0.08);
}

.log-row-compact.log-row-selected.level-error {
  background-color: rgba(220, 53, 69, 0.15);
}

.log-row-compact.log-row-selected.level-warn,
.log-row-compact.log-row-selected.level-warning {
  background-color: rgba(255, 193, 7, 0.15);
}
</style>

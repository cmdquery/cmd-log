<template>
  <div class="errors-page">
    <div class="section__header mb-6">
      <h1 class="page-title mb-0">Errors</h1>
      <div class="flex gap-2">
        <button class="btn btn--primary" @click="refresh">
          <span>↻</span>
          Refresh
        </button>
      </div>
    </div>

    <div class="filter-bar mb-6">
      <SearchBar
        v-model="searchQuery"
        @search="handleSearch"
        ref="searchBarRef"
        placeholder="Search errors..."
      />
      
      <div class="flex gap-2">
        <button
          v-for="filter in quickFilters"
          :key="filter.key"
          :class="['btn btn--sm', activeFilter === filter.key ? 'btn--brand' : 'btn--ghost']"
          @click="setFilter(filter.key)"
        >
          {{ filter.label }}
        </button>
      </div>

      <div class="filter-bar__group ml-auto">
        <select v-model="selectedEnvironment" @change="applyFilters" class="filter-bar__select">
          <option value="">Any Environment</option>
          <option value="production">Production</option>
          <option value="staging">Staging</option>
          <option value="development">Development</option>
        </select>

        <select v-model="selectedAssignee" @change="applyFilters" class="filter-bar__select">
          <option value="">Any Assignee</option>
          <option value="me">Me</option>
        </select>

        <select v-model="bulkAction" @change="handleBulkAction" class="filter-bar__select">
          <option value="">Bulk Actions</option>
          <option value="resolve">Resolve</option>
          <option value="unresolve">Unresolve</option>
          <option value="ignore">Ignore</option>
          <option value="delete">Delete</option>
        </select>
      </div>
    </div>

    <div class="errors-content">
      <div v-if="loading" class="loading-spinner">
        <div class="spinner"></div>
      </div>
      <div v-else-if="error" class="card card--empty">
        <div class="card__icon">⚠️</div>
        <div class="card__text">{{ error }}</div>
        <button @click="loadFaults" class="btn btn--primary">Retry</button>
      </div>
      <ErrorTable
        v-else
        :faults="faults"
        :one-hour-counts="oneHourCounts"
        @selection-change="handleSelectionChange"
        @status-update="handleStatusUpdate"
      />

      <div class="pagination" v-if="total > 0">
        <button
          class="pagination__btn"
          :disabled="offset === 0"
          @click="previousPage"
        >
          ← Previous
        </button>
        <span class="pagination__info">
          Showing {{ offset + 1 }} to {{ Math.min(offset + limit, total) }} of {{ total }}
        </span>
        <button
          class="pagination__btn"
          :disabled="offset + limit >= total"
          @click="nextPage"
        >
          Next →
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { fetchWithAuth } from '../services/api'
import SearchBar from '../components/SearchBar.vue'
import ErrorTable from '../components/ErrorTable.vue'

const searchQuery = ref('')
const activeFilter = ref('all')
const selectedEnvironment = ref('')
const selectedAssignee = ref('')
const bulkAction = ref('')
const faults = ref([])
const oneHourCounts = ref({})
const total = ref(0)
const limit = ref(50)
const offset = ref(0)
const selectedIds = ref([])
const searchBarRef = ref(null)
const loading = ref(false)
const error = ref(null)

const quickFilters = [
  { key: 'all', label: 'All' },
  { key: 'resolved', label: 'Resolved' },
  { key: 'unresolved', label: 'Unresolved' }
]

const setFilter = (key) => {
  activeFilter.value = key
  applyFilters()
}

const applyFilters = async () => {
  offset.value = 0
  await loadFaults()
}

const handleSearch = () => {
  applyFilters()
}

const loadFaults = async () => {
  loading.value = true
  error.value = null
  try {
    const params = new URLSearchParams()
    params.append('limit', limit.value.toString())
    params.append('offset', offset.value.toString())
    
    if (searchQuery.value) {
      params.append('q', searchQuery.value)
    }
    
    if (activeFilter.value === 'resolved') {
      params.append('q', (params.get('q') || '') + ' is:resolved')
    } else if (activeFilter.value === 'unresolved') {
      params.append('q', (params.get('q') || '') + ' -is:resolved')
    }
    
    if (selectedEnvironment.value) {
      params.append('q', (params.get('q') || '') + ` environment:${selectedEnvironment.value}`)
    }

    const response = await fetchWithAuth(`/api/v1/faults?${params.toString()}`)
    faults.value = response.faults || []
    total.value = response.total || 0

    // Load one-hour counts for each fault
    await loadOneHourCounts()
  } catch (err) {
    console.error('Error loading faults:', err)
    error.value = err.message || 'Failed to load errors'
    faults.value = []
    total.value = 0
  } finally {
    loading.value = false
  }
}

const loadOneHourCounts = async () => {
  const counts = {}
  for (const fault of faults.value) {
    try {
      const stats = await fetchWithAuth(`/api/v1/faults/${fault.id}/stats`)
      counts[fault.id] = stats.one_hour_count || 0
    } catch (error) {
      counts[fault.id] = 0
    }
  }
  oneHourCounts.value = counts
}

const handleSelectionChange = (ids) => {
  selectedIds.value = ids
}

const handleStatusUpdate = async ({ id, resolved }) => {
  try {
    const endpoint = resolved ? 'resolve' : 'unresolve'
    await fetchWithAuth(`/api/v1/faults/${id}/${endpoint}`, {
      method: 'POST'
    })
    await loadFaults()
  } catch (error) {
    console.error('Error updating status:', error)
  }
}

const handleBulkAction = async () => {
  if (!bulkAction.value || selectedIds.value.length === 0) {
    bulkAction.value = ''
    return
  }

  try {
    for (const id of selectedIds.value) {
      if (bulkAction.value === 'resolve') {
        await fetchWithAuth(`/api/v1/faults/${id}/resolve`, { method: 'POST' })
      } else if (bulkAction.value === 'unresolve') {
        await fetchWithAuth(`/api/v1/faults/${id}/unresolve`, { method: 'POST' })
      } else if (bulkAction.value === 'ignore') {
        await fetchWithAuth(`/api/v1/faults/${id}/ignore`, { method: 'POST' })
      } else if (bulkAction.value === 'delete') {
        await fetchWithAuth(`/api/v1/faults/${id}`, { method: 'DELETE' })
      }
    }
    bulkAction.value = ''
    selectedIds.value = []
    await loadFaults()
  } catch (error) {
    console.error('Error performing bulk action:', error)
  }
}

const previousPage = () => {
  if (offset.value > 0) {
    offset.value -= limit.value
    loadFaults()
  }
}

const nextPage = () => {
  if (offset.value + limit.value < total.value) {
    offset.value += limit.value
    loadFaults()
  }
}

const refresh = () => {
  loadFaults()
}

// Keyboard shortcuts
const handleKeyPress = (e) => {
  if (e.key === '/' && e.target.tagName !== 'INPUT') {
    e.preventDefault()
    searchBarRef.value?.focus()
  } else if (e.key === 'u' && e.ctrlKey) {
    e.preventDefault()
    setFilter('unresolved')
  } else if (e.key === 'r' && e.ctrlKey) {
    e.preventDefault()
    setFilter('resolved')
  } else if (e.key === 'a' && e.ctrlKey) {
    e.preventDefault()
    setFilter('all')
  }
}

onMounted(() => {
  loadFaults()
  window.addEventListener('keydown', handleKeyPress)
})

onUnmounted(() => {
  window.removeEventListener('keydown', handleKeyPress)
})
</script>

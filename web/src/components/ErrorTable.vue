<template>
  <div class="error-table-container">
    <table class="error-table">
      <thead>
        <tr>
          <th>
            <input
              type="checkbox"
              :checked="allSelected"
              @change="toggleAll"
            />
          </th>
          <th>Error Type</th>
          <th>Location</th>
          <th>Message</th>
          <th>Environment</th>
          <th>1 Hour</th>
          <th>Count</th>
          <th>Last</th>
          <th>Assignee</th>
          <th>Status</th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="fault in faults"
          :key="fault.id"
          :class="{ 'row-selected': selectedIds.has(fault.id) }"
          @click="handleRowClick(fault.id)"
        >
          <td @click.stop>
            <input
              type="checkbox"
              :checked="selectedIds.has(fault.id)"
              @change="toggleSelection(fault.id)"
            />
          </td>
          <td>
            <router-link :to="`/errors/${fault.id}`" class="error-link">
              {{ fault.error_class }}
            </router-link>
          </td>
          <td>{{ fault.location || 'unknown' }}</td>
          <td class="message-cell">{{ truncate(fault.message, 60) }}</td>
          <td>
            <span class="env-badge" :class="`env-${fault.environment}`">
              {{ fault.environment }}
            </span>
          </td>
          <td>{{ getOneHourCount(fault.id) }}</td>
          <td>{{ fault.occurrence_count }}</td>
          <td>{{ formatTime(fault.last_seen_at) }}</td>
          <td>
            <span v-if="fault.assignee" class="assignee">
              {{ fault.assignee.name || fault.assignee.email }}
            </span>
            <span v-else class="no-assignee">—</span>
          </td>
          <td>
            <StatusToggle
              :model-value="fault.resolved"
              @update:model-value="(val) => updateStatus(fault.id, val)"
            />
          </td>
        </tr>
      </tbody>
    </table>
    <div v-if="faults.length === 0" class="empty-state">
      No errors found
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import StatusToggle from './StatusToggle.vue'

const props = defineProps({
  faults: {
    type: Array,
    default: () => []
  },
  oneHourCounts: {
    type: Object,
    default: () => ({})
  }
})

const emit = defineEmits(['selection-change', 'status-update'])

const selectedIds = ref(new Set())

const allSelected = computed(() => {
  return props.faults.length > 0 && selectedIds.value.size === props.faults.length
})

const toggleAll = () => {
  if (allSelected.value) {
    selectedIds.value.clear()
  } else {
    props.faults.forEach(f => selectedIds.value.add(f.id))
  }
  emit('selection-change', Array.from(selectedIds.value))
}

const toggleSelection = (id) => {
  if (selectedIds.value.has(id)) {
    selectedIds.value.delete(id)
  } else {
    selectedIds.value.add(id)
  }
  emit('selection-change', Array.from(selectedIds.value))
}

const handleRowClick = (id) => {
  // Navigate to detail page
}

const updateStatus = (id, resolved) => {
  emit('status-update', { id, resolved })
}

const truncate = (str, len) => {
  if (!str) return ''
  return str.length > len ? str.substring(0, len) + '...' : str
}

const formatTime = (time) => {
  if (!time) return ''
  const date = new Date(time)
  const now = new Date()
  const diff = now - date
  const minutes = Math.floor(diff / 60000)
  const hours = Math.floor(minutes / 60)
  const days = Math.floor(hours / 24)
  
  if (minutes < 1) return 'just now'
  if (minutes < 60) return `${minutes}m ago`
  if (hours < 24) return `${hours}h ago`
  return `${days}d ago`
}

const getOneHourCount = (id) => {
  return props.oneHourCounts[id] || 0
}
</script>

<style scoped>
.error-table-container {
  background-color: #ffffff;
  border: 1px solid #e0e0e0;
  border-radius: 4px;
  overflow-x: auto;
}

.error-table {
  width: 100%;
  border-collapse: collapse;
}

.error-table th {
  background-color: #f5f5f5;
  padding: 0.75rem;
  text-align: left;
  font-weight: 600;
  font-size: 0.85rem;
  color: #666;
  border-bottom: 2px solid #e0e0e0;
}

.error-table td {
  padding: 0.75rem;
  border-bottom: 1px solid #f0f0f0;
}

.error-table tbody tr:hover {
  background-color: #f9f9f9;
}

.error-table tbody tr.row-selected {
  background-color: #e8f4f8;
}

.error-link {
  color: #3498db;
  text-decoration: none;
  font-weight: 500;
}

.error-link:hover {
  text-decoration: underline;
}

.message-cell {
  max-width: 300px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.env-badge {
  display: inline-block;
  padding: 0.25rem 0.5rem;
  border-radius: 3px;
  font-size: 0.75rem;
  font-weight: 500;
  text-transform: uppercase;
}

.env-production {
  background-color: #e74c3c;
  color: white;
}

.env-staging {
  background-color: #f39c12;
  color: white;
}

.env-development {
  background-color: #3498db;
  color: white;
}

.assignee {
  color: #666;
  font-size: 0.9rem;
}

.no-assignee {
  color: #999;
  font-style: italic;
}

.empty-state {
  text-align: center;
  padding: 3rem;
  color: #999;
}
</style>

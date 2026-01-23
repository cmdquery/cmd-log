<template>
  <div class="error-table-container">
    <table class="error-table">
      <thead>
        <tr>
          <th class="w-10">
            <input
              type="checkbox"
              class="table__checkbox"
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
              class="table__checkbox"
              :checked="selectedIds.has(fault.id)"
              @change="toggleSelection(fault.id)"
            />
          </td>
          <td>
            <router-link :to="`/errors/${fault.id}`" class="error-link">
              {{ fault.error_class }}
            </router-link>
          </td>
          <td class="text-muted">{{ fault.location || 'unknown' }}</td>
          <td class="message-cell">{{ truncate(fault.message, 60) }}</td>
          <td>
            <span class="env-badge" :class="`env-${fault.environment}`">
              {{ fault.environment }}
            </span>
          </td>
          <td>
            <span :class="getOneHourCount(fault.id) > 0 ? 'text-body' : 'text-muted'">
              {{ getOneHourCount(fault.id) }}
            </span>
          </td>
          <td>
            <span class="badge badge--xs">{{ fault.occurrence_count }}</span>
          </td>
          <td class="text-muted">{{ formatTime(fault.last_seen_at) }}</td>
          <td>
            <span v-if="fault.assignee" class="assignee">
              {{ fault.assignee.name || fault.assignee.email }}
            </span>
            <span v-else class="no-assignee">—</span>
          </td>
          <td @click.stop>
            <StatusToggle
              :model-value="fault.resolved"
              @update:model-value="(val) => updateStatus(fault.id, val)"
            />
          </td>
        </tr>
      </tbody>
    </table>
    <div v-if="faults.length === 0" class="empty-state">
      <div class="empty-state__icon">📭</div>
      <div class="empty-state__text">No errors found</div>
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

<template>
  <div class="breadcrumb-viewer">
    <div class="breadcrumb-viewer__header">
      <span class="breadcrumb-viewer__title">Breadcrumbs</span>
    </div>
    <div v-if="!breadcrumbs || breadcrumbs.length === 0" class="empty-state p-6">
      <div class="empty-state__icon">🍞</div>
      <div class="empty-state__text">No breadcrumbs available</div>
    </div>
    <div v-else>
      <div
        v-for="(crumb, index) in breadcrumbs"
        :key="index"
        class="breadcrumb-viewer__item"
      >
        <span class="breadcrumb-viewer__time">{{ formatTime(crumb.time) }}</span>
        <span :class="['breadcrumb-viewer__category', getCategoryColor(crumb.category)]">
          {{ crumb.category }}
        </span>
        <span class="breadcrumb-viewer__message">{{ crumb.message }}</span>
        <div v-if="crumb.metadata && Object.keys(crumb.metadata).length > 0" class="breadcrumb-viewer__data">
          {{ JSON.stringify(crumb.metadata, null, 2) }}
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
const props = defineProps({
  breadcrumbs: {
    type: Array,
    default: () => []
  }
})

const formatTime = (time) => {
  if (!time) return ''
  const date = new Date(time)
  return date.toLocaleTimeString()
}

const getCategoryColor = (category) => {
  const colors = {
    'http': 'text-blue',
    'navigation': 'text-green',
    'click': 'text-purple',
    'console': 'text-orange',
    'error': 'text-red'
  }
  return colors[category?.toLowerCase()] || ''
}
</script>

<style>
.text-blue { color: var(--color-blue); }
.text-green { color: var(--color-green); }
.text-purple { color: var(--color-purple); }
.text-orange { color: var(--color-orange); }
.text-red { color: var(--color-red); }
</style>

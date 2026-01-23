<template>
  <div class="breadcrumb-viewer">
    <div v-if="!breadcrumbs || breadcrumbs.length === 0" class="empty">
      No breadcrumbs available
    </div>
    <div v-else class="breadcrumb-list">
      <div
        v-for="(crumb, index) in breadcrumbs"
        :key="index"
        class="breadcrumb-item"
      >
        <div class="breadcrumb-header">
          <span class="breadcrumb-category">{{ crumb.category }}</span>
          <span class="breadcrumb-time">{{ formatTime(crumb.time) }}</span>
        </div>
        <div class="breadcrumb-message">{{ crumb.message }}</div>
        <div v-if="crumb.metadata && Object.keys(crumb.metadata).length > 0" class="breadcrumb-metadata">
          <pre>{{ JSON.stringify(crumb.metadata, null, 2) }}</pre>
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
  return date.toLocaleString()
}
</script>

<style scoped>
.breadcrumb-viewer {
  background-color: #ffffff;
  border: 1px solid #e0e0e0;
  border-radius: 4px;
  padding: 1rem;
}

.empty {
  text-align: center;
  color: #999;
  padding: 2rem;
}

.breadcrumb-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.breadcrumb-item {
  border-left: 3px solid #3498db;
  padding-left: 1rem;
  padding-bottom: 1rem;
}

.breadcrumb-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 0.5rem;
}

.breadcrumb-category {
  font-weight: 600;
  color: #3498db;
  text-transform: uppercase;
  font-size: 0.85rem;
}

.breadcrumb-time {
  color: #999;
  font-size: 0.85rem;
}

.breadcrumb-message {
  color: #333;
  margin-bottom: 0.5rem;
}

.breadcrumb-metadata {
  background-color: #f5f5f5;
  padding: 0.5rem;
  border-radius: 3px;
  margin-top: 0.5rem;
}

.breadcrumb-metadata pre {
  margin: 0;
  font-size: 0.85rem;
  color: #666;
}
</style>

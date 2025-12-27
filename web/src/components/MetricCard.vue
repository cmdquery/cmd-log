<template>
  <div class="metric-card">
    <h3>{{ title }}</h3>
    <div class="metric-value">
      <slot>{{ value }}</slot>
    </div>
  </div>
</template>

<script setup>
defineProps({
  title: {
    type: String,
    required: true
  },
  value: {
    type: [String, Number],
    default: '-'
  }
})
</script>

<style scoped>
.metric-card {
  background: white;
  padding: 1.75rem;
  border-radius: 12px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.08);
  transition: all 0.2s ease;
}

.metric-card:hover {
  box-shadow: 0 4px 12px rgba(0,0,0,0.12);
  transform: translateY(-2px);
}

.metric-card h3 {
  font-size: 0.85rem;
  color: #666;
  margin-bottom: 0.75rem;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  font-weight: 600;
}

.metric-value {
  font-size: 2rem;
  font-weight: 600;
  color: #2c3e50;
  max-width: 100%;
  overflow: hidden;
  overflow-wrap: break-word;
  word-break: break-word;
  line-height: 1.2;
}
</style>



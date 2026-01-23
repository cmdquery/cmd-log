<template>
  <div class="metric-card">
    <div class="metric-card__title">{{ title }}</div>
    <div class="metric-card__value">
      <slot name="content">
        {{ value }}
      </slot>
    </div>
    <slot></slot>
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

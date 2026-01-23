<template>
  <div class="loading-spinner">
    <div class="spinner"></div>
    <p v-if="message" class="text-muted">{{ message }}</p>
  </div>
</template>

<script setup>
defineProps({
  message: {
    type: String,
    default: 'Loading...'
  }
})
</script>

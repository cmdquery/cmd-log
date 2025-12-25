<template>
  <div v-if="message" :class="['notification', `notification-${type}`, { show: visible }]">
    {{ message }}
  </div>
</template>

<script setup>
import { ref, watch, onMounted } from 'vue'

const props = defineProps({
  message: {
    type: String,
    default: ''
  },
  type: {
    type: String,
    default: 'info'
  }
})

const visible = ref(false)

watch(() => props.message, (newVal) => {
  if (newVal) {
    visible.value = true
    setTimeout(() => {
      visible.value = false
      setTimeout(() => {
        emit('close')
      }, 300)
    }, 3000)
  }
})

const emit = defineEmits(['close'])

onMounted(() => {
  if (props.message) {
    visible.value = true
  }
})
</script>

<style scoped>
.notification {
  position: fixed;
  top: 20px;
  right: 20px;
  padding: 1rem 1.5rem;
  border-radius: 4px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.2);
  z-index: 1000;
  opacity: 0;
  transform: translateX(100%);
  transition: all 0.3s ease;
}

.notification.show {
  opacity: 1;
  transform: translateX(0);
}

.notification-info {
  background-color: #3498db;
  color: white;
}

.notification-success {
  background-color: #27ae60;
  color: white;
}

.notification-error {
  background-color: #e74c3c;
  color: white;
}
</style>


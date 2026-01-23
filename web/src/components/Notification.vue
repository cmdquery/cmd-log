<template>
  <div v-if="message" :class="['notification', `notification--${type}`, { 'show': visible }]">
    <span class="notification__content">{{ message }}</span>
    <button class="notification__close" @click="close">×</button>
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
const emit = defineEmits(['close'])

const close = () => {
  visible.value = false
  setTimeout(() => {
    emit('close')
  }, 300)
}

watch(() => props.message, (newVal) => {
  if (newVal) {
    visible.value = true
    setTimeout(() => {
      close()
    }, 3000)
  }
})

onMounted(() => {
  if (props.message) {
    visible.value = true
  }
})
</script>

<style>
.notification {
  position: fixed;
  top: var(--space-4);
  right: var(--space-4);
  display: flex;
  align-items: center;
  gap: var(--space-3);
  min-width: 300px;
  max-width: 28rem;
  padding: var(--space-4) var(--space-6);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-lg);
  z-index: var(--z-toast);
  opacity: 0;
  transform: translateX(100%);
  transition: all 0.3s ease;
}

.notification.show {
  opacity: 1;
  transform: translateX(0);
}

.notification--success {
  background-color: var(--color-green);
  color: #ffffff;
}

.notification--error {
  background-color: var(--color-red);
  color: #ffffff;
}

.notification--warning {
  background-color: var(--color-orange);
  color: #ffffff;
}

.notification--info {
  background-color: var(--color-blue);
  color: #ffffff;
}

.notification__content {
  flex: 1;
  font-size: var(--text-small);
}

.notification__close {
  color: inherit;
  opacity: 0.8;
  cursor: pointer;
  font-size: 1.5rem;
  line-height: 1;
  background: none;
  border: none;
  padding: 0;
  transition: opacity 0.15s;
}

.notification__close:hover {
  opacity: 1;
}
</style>

<template>
  <label class="status-toggle">
    <input
      type="checkbox"
      :checked="modelValue"
      @change="handleChange"
      class="status-toggle__input"
    />
    <span class="status-toggle__switch" :class="{ 'is-active': modelValue }"></span>
    <span class="status-toggle__label">{{ modelValue ? resolvedLabel : unresolvedLabel }}</span>
  </label>
</template>

<script setup>
const props = defineProps({
  modelValue: Boolean,
  resolvedLabel: {
    type: String,
    default: 'Resolved'
  },
  unresolvedLabel: {
    type: String,
    default: 'Unresolved'
  }
})

const emit = defineEmits(['update:modelValue'])

const handleChange = (e) => {
  emit('update:modelValue', e.target.checked)
}
</script>

<style>
.status-toggle {
  display: inline-flex;
  align-items: center;
  gap: var(--space-2);
  cursor: pointer;
}

.status-toggle__input {
  position: absolute;
  opacity: 0;
  width: 0;
  height: 0;
}

.status-toggle__switch {
  position: relative;
  width: 36px;
  height: 20px;
  background-color: var(--bg-level-3);
  border: 1px solid var(--border-primary);
  border-radius: var(--radius-full);
  transition: background-color 0.2s, border-color 0.2s;
}

.status-toggle__switch::after {
  content: '';
  position: absolute;
  top: 2px;
  left: 2px;
  width: 14px;
  height: 14px;
  background-color: var(--text-tertiary);
  border-radius: var(--radius-circle);
  transition: transform 0.2s, background-color 0.2s;
}

.status-toggle__switch.is-active {
  background-color: var(--color-green);
  border-color: var(--color-green);
}

.status-toggle__switch.is-active::after {
  transform: translateX(16px);
  background-color: #ffffff;
}

.status-toggle__label {
  font-size: var(--text-micro);
  color: var(--text-tertiary);
}
</style>

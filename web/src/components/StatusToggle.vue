<template>
  <label class="status-toggle">
    <input
      type="checkbox"
      :checked="modelValue"
      @change="handleChange"
      class="toggle-input"
    />
    <span class="toggle-slider"></span>
    <span class="toggle-label">{{ modelValue ? resolvedLabel : unresolvedLabel }}</span>
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

<style scoped>
.status-toggle {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  cursor: pointer;
}

.toggle-input {
  display: none;
}

.toggle-slider {
  position: relative;
  width: 44px;
  height: 24px;
  background-color: #ccc;
  border-radius: 12px;
  transition: background-color 0.3s;
}

.toggle-slider::before {
  content: '';
  position: absolute;
  width: 18px;
  height: 18px;
  border-radius: 50%;
  background-color: white;
  top: 3px;
  left: 3px;
  transition: transform 0.3s;
}

.toggle-input:checked + .toggle-slider {
  background-color: #27ae60;
}

.toggle-input:checked + .toggle-slider::before {
  transform: translateX(20px);
}

.toggle-label {
  font-size: 0.9rem;
  color: #666;
}
</style>

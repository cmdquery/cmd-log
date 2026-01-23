<template>
  <div class="search-bar">
    <span class="search-bar__icon">🔍</span>
    <input
      type="text"
      v-model="query"
      @input="handleInput"
      @keydown.enter="handleSearch"
      @keydown.esc="handleEscape"
      :placeholder="placeholder"
      class="search-bar__input"
      ref="inputRef"
    />
    <button @click="handleSearch" class="btn btn--primary btn--sm">Search</button>
  </div>
</template>

<script setup>
import { ref, watch } from 'vue'

const props = defineProps({
  modelValue: String,
  placeholder: {
    type: String,
    default: 'Search errors (e.g., is:resolved, environment:production)'
  }
})

const emit = defineEmits(['update:modelValue', 'search'])

const query = ref(props.modelValue || '')
const inputRef = ref(null)

watch(() => props.modelValue, (newVal) => {
  query.value = newVal || ''
})

const handleInput = () => {
  emit('update:modelValue', query.value)
}

const handleSearch = () => {
  emit('search', query.value)
}

const handleEscape = () => {
  query.value = ''
  emit('update:modelValue', '')
  inputRef.value?.blur()
}

defineExpose({
  focus: () => inputRef.value?.focus()
})
</script>

<style>
.search-bar {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  position: relative;
  flex: 1;
  max-width: 400px;
}

.search-bar__icon {
  position: absolute;
  left: var(--space-3);
  color: var(--text-quaternary);
  pointer-events: none;
  font-size: var(--text-small);
}

.search-bar__input {
  flex: 1;
  padding: var(--space-2) var(--space-4);
  padding-left: var(--space-10);
  font-size: var(--text-small);
  background-color: var(--bg-level-2);
  border: 1px solid var(--border-primary);
  border-radius: var(--radius-md);
  color: var(--text-primary);
  transition: border-color 0.15s, box-shadow 0.15s;
}

.search-bar__input::placeholder {
  color: var(--text-quaternary);
}

.search-bar__input:focus {
  outline: none;
  border-color: var(--color-accent);
  box-shadow: 0 0 0 3px var(--color-accent-tint);
}
</style>

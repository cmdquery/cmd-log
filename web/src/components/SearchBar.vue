<template>
  <div class="search-bar">
    <input
      type="text"
      v-model="query"
      @input="handleInput"
      @keydown.enter="handleSearch"
      @keydown.esc="handleEscape"
      :placeholder="placeholder"
      class="search-input"
      ref="inputRef"
    />
    <button @click="handleSearch" class="search-button">Search</button>
  </div>
</template>

<script setup>
import { ref, watch, onMounted } from 'vue'

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

// Expose focus method for keyboard shortcuts
defineExpose({
  focus: () => inputRef.value?.focus()
})
</script>

<style scoped>
.search-bar {
  display: flex;
  gap: 0.5rem;
  margin-bottom: 1rem;
}

.search-input {
  flex: 1;
  padding: 0.75rem 1rem;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 0.95rem;
}

.search-input:focus {
  outline: none;
  border-color: #3498db;
  box-shadow: 0 0 0 3px rgba(52, 152, 219, 0.1);
}

.search-button {
  padding: 0.75rem 1.5rem;
  background-color: #3498db;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-weight: 500;
}

.search-button:hover {
  background-color: #2980b9;
}
</style>

<template>
  <div class="api-keys-page">
    <h1 class="page-title">API Keys</h1>
    
    <!-- Create API Key Form -->
    <div class="card mb-6">
      <div class="card__header">
        <h3 class="h5">Create New API Key</h3>
      </div>
      <form @submit.prevent="createKey">
        <div class="form-group">
          <label class="form-label" for="key-name">
            Name <span class="required">*</span>
          </label>
          <input
            type="text"
            id="key-name"
            class="form-input"
            v-model="newKey.name"
            required
            placeholder="e.g., Production API Key"
          />
        </div>
        <div class="form-group">
          <label class="form-label" for="key-description">Description</label>
          <textarea
            id="key-description"
            class="form-textarea"
            v-model="newKey.description"
            rows="3"
            placeholder="Optional description"
          ></textarea>
        </div>
        <button type="submit" class="btn btn--brand" :disabled="creating">
          {{ creating ? 'Creating...' : 'Create API Key' }}
        </button>
      </form>
    </div>
    
    <!-- API Keys List -->
    <div class="card">
      <div class="card__header">
        <h3 class="h5">Existing API Keys</h3>
      </div>
      
      <div v-if="loading" class="loading-spinner">
        <div class="spinner"></div>
      </div>
      <div v-else-if="error" class="alert alert--error">{{ error }}</div>
      <div v-else-if="keys.length === 0" class="empty-state">
        <div class="empty-state__icon">🔑</div>
        <div class="empty-state__text">No API keys found. Create one above.</div>
      </div>
      
      <div v-else class="table-container">
        <table class="table">
          <thead>
            <tr>
              <th>ID</th>
              <th>Name</th>
              <th>Description</th>
              <th v-if="userIsAdmin">Created By</th>
              <th>Created</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="key in keys" :key="key.id">
              <td class="text-muted">{{ key.id }}</td>
              <td>{{ key.name }}</td>
              <td class="text-muted">{{ key.description || '—' }}</td>
              <td v-if="userIsAdmin" class="text-muted">{{ key.created_by_user_id ?? '—' }}</td>
              <td class="text-muted">{{ formatDate(key.created_at) }}</td>
              <td>
                <span :class="['badge', key.is_active ? 'badge--success' : 'badge--error']">
                  {{ key.is_active ? 'Active' : 'Inactive' }}
                </span>
              </td>
              <td>
                <button
                  v-if="key.is_active"
                  @click="deleteKey(key.id)"
                  class="btn btn--danger btn--sm"
                  :disabled="deleting === key.id"
                >
                  {{ deleting === key.id ? 'Deleting...' : 'Delete' }}
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    
    <!-- Modal for displaying newly created key -->
    <div v-if="showModal" class="modal" @click.self="closeModal">
      <div class="modal__content">
        <div class="modal__inner">
          <div class="modal__header">
            <h3 class="modal__title">API Key Created</h3>
            <button class="modal__close" @click="closeModal">&times;</button>
          </div>
          <div class="modal__body">
            <div class="alert alert--warning mb-4">
              <strong>Important:</strong> Copy this API key now. It won't be shown again.
            </div>
            <div class="code-block">
              <div class="code-block__content">
                <pre>{{ createdKeyValue }}</pre>
              </div>
            </div>
          </div>
          <div class="modal__footer">
            <button @click="copyToClipboard" class="btn btn--brand">
              Copy to Clipboard
            </button>
            <button @click="closeModal" class="btn btn--secondary">
              Close
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { listAPIKeys, createAPIKey, deleteAPIKey, isAdmin } from '../services/api'

const keys = ref([])
const loading = ref(false)
const error = ref('')
const creating = ref(false)
const deleting = ref(null)
const showModal = ref(false)
const createdKeyValue = ref('')
const userIsAdmin = isAdmin()

const newKey = ref({
  name: '',
  description: ''
})

const formatDate = (dateString) => {
  return new Date(dateString).toLocaleString()
}

const loadKeys = async () => {
  loading.value = true
  error.value = ''
  try {
    const data = await listAPIKeys()
    keys.value = data.keys || []
  } catch (err) {
    error.value = err.message || 'Failed to load API keys'
  } finally {
    loading.value = false
  }
}

const createKey = async () => {
  creating.value = true
  error.value = ''
  try {
    const data = await createAPIKey(newKey.value.name, newKey.value.description)
    createdKeyValue.value = data.key
    showModal.value = true
    newKey.value = { name: '', description: '' }
    await loadKeys()
  } catch (err) {
    error.value = err.message || 'Failed to create API key'
  } finally {
    creating.value = false
  }
}

const deleteKey = async (id) => {
  if (!confirm('Are you sure you want to delete this API key? This action cannot be undone.')) {
    return
  }
  
  deleting.value = id
  try {
    await deleteAPIKey(id)
    await loadKeys()
  } catch (err) {
    error.value = err.message || 'Failed to delete API key'
  } finally {
    deleting.value = null
  }
}

const closeModal = () => {
  showModal.value = false
  createdKeyValue.value = ''
}

const copyToClipboard = async () => {
  try {
    await navigator.clipboard.writeText(createdKeyValue.value)
    alert('API key copied to clipboard')
  } catch (err) {
    alert('Failed to copy to clipboard')
  }
}

onMounted(() => {
  loadKeys()
})
</script>

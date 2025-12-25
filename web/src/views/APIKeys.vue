<template>
  <div class="api-keys-page">
    <h2 class="page-title">API Keys</h2>
    
    <!-- Create API Key Form -->
    <div class="card" style="margin-bottom: 2rem;">
      <h3>Create New API Key</h3>
      <form @submit.prevent="createKey">
        <div class="form-group">
          <label for="key-name">Name *</label>
          <input
            type="text"
            id="key-name"
            v-model="newKey.name"
            required
            placeholder="e.g., Production API Key"
          />
        </div>
        <div class="form-group">
          <label for="key-description">Description</label>
          <textarea
            id="key-description"
            v-model="newKey.description"
            rows="3"
            placeholder="Optional description"
          ></textarea>
        </div>
        <button type="submit" class="btn btn-primary" :disabled="creating">
          {{ creating ? 'Creating...' : 'Create API Key' }}
        </button>
      </form>
    </div>
    
    <!-- API Keys List -->
    <div class="card">
      <h3>Existing API Keys</h3>
      <div v-if="loading" class="loading">Loading API keys...</div>
      <div v-else-if="error" class="error">{{ error }}</div>
      <div v-else-if="keys.length === 0" class="empty">No API keys found. Create one above.</div>
      <table v-else class="keys-table">
        <thead>
          <tr>
            <th>ID</th>
            <th>Name</th>
            <th>Description</th>
            <th>Created</th>
            <th>Status</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="key in keys" :key="key.id">
            <td>{{ key.id }}</td>
            <td>{{ key.name }}</td>
            <td>{{ key.description || '-' }}</td>
            <td>{{ formatDate(key.created_at) }}</td>
            <td>
              <span :class="['key-status', key.is_active ? 'active' : 'inactive']">
                {{ key.is_active ? 'Active' : 'Inactive' }}
              </span>
            </td>
            <td>
              <button
                v-if="key.is_active"
                @click="deleteKey(key.id)"
                class="btn btn-danger"
                :disabled="deleting === key.id"
              >
                {{ deleting === key.id ? 'Deleting...' : 'Delete' }}
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    
    <!-- Modal for displaying newly created key -->
    <div v-if="showModal" class="modal" @click.self="closeModal">
      <div class="modal-content">
        <span class="close" @click="closeModal">&times;</span>
        <h3>API Key Created</h3>
        <p><strong>Important:</strong> Copy this API key now. It won't be shown again.</p>
        <div class="key-display">
          <code>{{ createdKeyValue }}</code>
          <button @click="copyToClipboard" class="btn btn-secondary" style="margin-top: 1rem;">
            Copy to Clipboard
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { listAPIKeys, createAPIKey, deleteAPIKey } from '../services/api'

const keys = ref([])
const loading = ref(false)
const error = ref('')
const creating = ref(false)
const deleting = ref(null)
const showModal = ref(false)
const createdKeyValue = ref('')

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
    console.log('API keys loaded successfully:', data)
    keys.value = data.keys || []
  } catch (err) {
    error.value = err.message || 'Failed to load API keys'
    console.error('Error loading API keys:', {
      message: err.message,
      error: err,
      stack: err.stack
    })
  } finally {
    loading.value = false
  }
}

const createKey = async () => {
  creating.value = true
  error.value = ''
  try {
    console.log('Creating API key:', { name: newKey.value.name, description: newKey.value.description })
    const data = await createAPIKey(newKey.value.name, newKey.value.description)
    console.log('API key created successfully:', { id: data.id, name: data.name })
    createdKeyValue.value = data.key
    showModal.value = true
    newKey.value = { name: '', description: '' }
    await loadKeys()
  } catch (err) {
    error.value = err.message || 'Failed to create API key'
    console.error('Error creating API key:', {
      message: err.message,
      error: err,
      stack: err.stack,
      requestData: { name: newKey.value.name, description: newKey.value.description }
    })
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
    console.log('Deleting API key:', id)
    await deleteAPIKey(id)
    console.log('API key deleted successfully:', id)
    await loadKeys()
  } catch (err) {
    error.value = err.message || 'Failed to delete API key'
    console.error('Error deleting API key:', {
      message: err.message,
      error: err,
      stack: err.stack,
      keyId: id
    })
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
    console.error('Failed to copy:', err)
    alert('Failed to copy to clipboard')
  }
}

onMounted(() => {
  loadKeys()
})
</script>

<style scoped>
.api-keys-page {
  padding: 1rem 0;
}

.card {
  background: white;
  padding: 2rem;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.card h3 {
  margin-bottom: 1.5rem;
  color: #2c3e50;
}

.form-group {
  margin-bottom: 1.5rem;
}

.form-group label {
  display: block;
  margin-bottom: 0.5rem;
  font-weight: 500;
  color: #333;
}

.form-group input[type="text"],
.form-group textarea {
  width: 100%;
  padding: 0.75rem;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 1rem;
  font-family: inherit;
}

.form-group textarea {
  resize: vertical;
}

.keys-table {
  width: 100%;
  border-collapse: collapse;
}

.keys-table th,
.keys-table td {
  padding: 1rem;
  text-align: left;
  border-bottom: 1px solid #ddd;
}

.keys-table th {
  background-color: #f8f9fa;
  font-weight: 600;
  color: #2c3e50;
}

.keys-table tr:hover {
  background-color: #f8f9fa;
}

.key-status {
  padding: 0.25rem 0.75rem;
  border-radius: 12px;
  font-size: 0.875rem;
  font-weight: 500;
}

.key-status.active {
  background-color: #d4edda;
  color: #155724;
}

.key-status.inactive {
  background-color: #f8d7da;
  color: #721c24;
}

.modal {
  position: fixed;
  z-index: 1000;
  left: 0;
  top: 0;
  width: 100%;
  height: 100%;
  background-color: rgba(0,0,0,0.5);
  display: flex;
  align-items: center;
  justify-content: center;
}

.modal-content {
  background-color: white;
  padding: 2rem;
  border-radius: 8px;
  max-width: 600px;
  width: 90%;
  position: relative;
}

.modal-content .close {
  position: absolute;
  right: 1rem;
  top: 1rem;
  font-size: 2rem;
  font-weight: bold;
  cursor: pointer;
  color: #999;
}

.modal-content .close:hover {
  color: #333;
}

.key-display {
  margin-top: 1rem;
  padding: 1rem;
  background-color: #f8f9fa;
  border-radius: 4px;
}

.key-display code {
  display: block;
  word-break: break-all;
  font-family: 'Courier New', monospace;
  font-size: 0.9rem;
  color: #2c3e50;
}
</style>


<template>
  <div class="error-detail-page" v-if="fault">
    <div class="error-header">
      <div class="header-main">
        <h1 class="error-class">{{ fault.error_class }}</h1>
        <div class="error-meta">
          <span class="timestamp">{{ formatTime(fault.last_seen_at) }}</span>
        </div>
      </div>
      <div class="header-actions">
        <button class="nav-btn" @click="navigateOccurrence('first')">First</button>
        <button class="nav-btn" @click="navigateOccurrence('prev')">Previous</button>
        <button class="nav-btn" @click="navigateOccurrence('next')">Next</button>
        <button class="nav-btn" @click="navigateOccurrence('last')">Last</button>
      </div>
    </div>

    <div class="error-content">
      <div class="error-main">
        <div class="tabs">
          <button
            v-for="tab in tabs"
            :key="tab.key"
            :class="['tab-btn', { active: activeTab === tab.key }]"
            @click="activeTab = tab.key"
          >
            {{ tab.label }}
          </button>
        </div>

        <div class="tab-content">
          <!-- Summary Tab -->
          <div v-if="activeTab === 'summary'" class="tab-panel">
            <div class="summary-section">
              <div class="status-section">
                <StatusToggle
                  v-model="fault.resolved"
                  @update:model-value="updateResolved"
                />
              </div>
              
              <div class="message-section">
                <h3>Message</h3>
                <pre class="message-block">{{ fault.message }}</pre>
              </div>

              <div class="backtrace-section" v-if="currentNotice && currentNotice.backtrace">
                <h3>Backtrace</h3>
                <BacktraceViewer :backtrace="currentNotice.backtrace" />
              </div>

              <div class="location-section">
                <h3>Location</h3>
                <p>
                  <span class="env-badge" :class="`env-${fault.environment}`">
                    {{ fault.environment }}
                  </span>
                  <span v-if="currentNotice && currentNotice.hostname">
                    on {{ currentNotice.hostname }}
                  </span>
                </p>
              </div>

              <div class="tags-section">
                <h3>Tags</h3>
                <div class="tags-list">
                  <span v-for="tag in fault.tags" :key="tag" class="tag">
                    {{ tag }}
                  </span>
                  <button class="add-tag-btn" @click="showAddTag = true">+ Add Tag</button>
                </div>
              </div>
            </div>
          </div>

          <!-- Comments Tab -->
          <div v-if="activeTab === 'comments'" class="tab-panel">
            <div class="comments-section">
              <div class="comment-form">
                <textarea
                  v-model="newComment"
                  placeholder="Add a comment..."
                  class="comment-input"
                ></textarea>
                <button @click="addComment" class="btn btn-primary">Add Comment</button>
              </div>
              <div class="comments-list">
                <div v-for="comment in comments" :key="comment.id" class="comment-item">
                  <div class="comment-header">
                    <span class="comment-author">{{ comment.user?.name || 'Unknown' }}</span>
                    <span class="comment-time">{{ formatTime(comment.created_at) }}</span>
                  </div>
                  <div class="comment-body">{{ comment.comment }}</div>
                </div>
              </div>
            </div>
          </div>

          <!-- Backtrace Tab -->
          <div v-if="activeTab === 'backtrace'" class="tab-panel">
            <BacktraceViewer :backtrace="currentNotice?.backtrace || []" />
          </div>

          <!-- Context Tab -->
          <div v-if="activeTab === 'context'" class="tab-panel">
            <div class="context-viewer">
              <h3>Custom Context</h3>
              <pre v-if="currentNotice && currentNotice.context">
                {{ JSON.stringify(currentNotice.context, null, 2) }}
              </pre>
              <p v-else>No context data available</p>
            </div>
          </div>

          <!-- Breadcrumbs Tab -->
          <div v-if="activeTab === 'breadcrumbs'" class="tab-panel">
            <BreadcrumbViewer :breadcrumbs="currentNotice?.breadcrumbs || []" />
          </div>

          <!-- Environment Tab -->
          <div v-if="activeTab === 'environment'" class="tab-panel">
            <div class="environment-viewer">
              <h3>Application Environment</h3>
              <pre v-if="currentNotice && currentNotice.environment">
                {{ JSON.stringify(currentNotice.environment, null, 2) }}
              </pre>
              <p v-else>No environment data available</p>
            </div>
          </div>

          <!-- History Tab -->
          <div v-if="activeTab === 'history'" class="tab-panel">
            <div class="history-list">
              <div v-for="entry in history" :key="entry.id" class="history-item">
                <div class="history-action">{{ entry.action }}</div>
                <div class="history-user" v-if="entry.user">
                  {{ entry.user.name || entry.user.email }}
                </div>
                <div class="history-time">{{ formatTime(entry.created_at) }}</div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="error-sidebar">
        <div class="sidebar-widget">
          <h3>Total Occurrences</h3>
          <div class="stat-value">{{ stats?.total_occurrences || 0 }}</div>
        </div>

        <div class="sidebar-widget">
          <h3>Most Recently Occurred</h3>
          <div class="stat-value">{{ formatTime(stats?.last_occurred) }}</div>
        </div>

        <div class="sidebar-widget">
          <h3>First Occurred</h3>
          <div class="stat-value">{{ formatTime(stats?.first_occurred) }}</div>
        </div>

        <div class="action-bar">
          <h3>Actions</h3>
          <button class="action-btn" @click="assignFault">Assign</button>
          <button class="action-btn" @click="ignoreFault">Ignore</button>
          <button class="action-btn" @click="exportFault">Export</button>
          <button class="action-btn" @click="deleteFault">Delete</button>
        </div>
      </div>
    </div>
  </div>
  <div v-else class="loading">Loading...</div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { fetchWithAuth } from '../services/api'
import StatusToggle from '../components/StatusToggle.vue'
import BacktraceViewer from '../components/BacktraceViewer.vue'
import BreadcrumbViewer from '../components/BreadcrumbViewer.vue'

const route = useRoute()
const router = useRouter()

const fault = ref(null)
const currentNotice = ref(null)
const comments = ref([])
const history = ref([])
const stats = ref(null)
const activeTab = ref('summary')
const newComment = ref('')
const showAddTag = ref(false)

const tabs = [
  { key: 'summary', label: 'Summary' },
  { key: 'comments', label: 'Comments' },
  { key: 'backtrace', label: 'Backtrace' },
  { key: 'context', label: 'Context' },
  { key: 'breadcrumbs', label: 'Breadcrumbs' },
  { key: 'environment', label: 'Environment' },
  { key: 'history', label: 'History' }
]

const loadFault = async () => {
  try {
    const id = route.params.id
    fault.value = await fetchWithAuth(`/api/v1/faults/${id}`)
    
    // Load first notice
    const noticesResponse = await fetchWithAuth(`/api/v1/faults/${id}/notices?limit=1`)
    if (noticesResponse.notices && noticesResponse.notices.length > 0) {
      currentNotice.value = noticesResponse.notices[0]
    }
    
    // Load stats
    stats.value = await fetchWithAuth(`/api/v1/faults/${id}/stats`)
    
    // Load comments
    const commentsResponse = await fetchWithAuth(`/api/v1/faults/${id}/comments`)
    comments.value = commentsResponse.comments || []
    
    // Load history
    const historyResponse = await fetchWithAuth(`/api/v1/faults/${id}/history`)
    history.value = historyResponse.history || []
  } catch (error) {
    console.error('Error loading fault:', error)
  }
}

const updateResolved = async (resolved) => {
  try {
    const endpoint = resolved ? 'resolve' : 'unresolve'
    await fetchWithAuth(`/api/v1/faults/${fault.value.id}/${endpoint}`, {
      method: 'POST'
    })
    await loadFault()
  } catch (error) {
    console.error('Error updating resolved status:', error)
  }
}

const addComment = async () => {
  if (!newComment.value.trim()) return
  
  try {
    // TODO: Get user ID from auth
    await fetchWithAuth(`/api/v1/faults/${fault.value.id}/comments`, {
      method: 'POST',
      body: JSON.stringify({
        comment: newComment.value,
        user_id: 1 // Placeholder
      })
    })
    newComment.value = ''
    await loadFault()
  } catch (error) {
    console.error('Error adding comment:', error)
  }
}

const assignFault = async () => {
  // TODO: Implement assign dialog
  console.log('Assign fault')
}

const ignoreFault = async () => {
  try {
    await fetchWithAuth(`/api/v1/faults/${fault.value.id}/ignore`, {
      method: 'POST'
    })
    await loadFault()
  } catch (error) {
    console.error('Error ignoring fault:', error)
  }
}

const exportFault = () => {
  // TODO: Implement export
  console.log('Export fault')
}

const deleteFault = async () => {
  if (!confirm('Are you sure you want to delete this error?')) return
  
  try {
    await fetchWithAuth(`/api/v1/faults/${fault.value.id}`, {
      method: 'DELETE'
    })
    router.push('/errors')
  } catch (error) {
    console.error('Error deleting fault:', error)
  }
}

const navigateOccurrence = (direction) => {
  // TODO: Implement navigation
  console.log('Navigate', direction)
}

const formatTime = (time) => {
  if (!time) return ''
  const date = new Date(time)
  return date.toLocaleString()
}

onMounted(() => {
  loadFault()
})
</script>

<style scoped>
.error-detail-page {
  padding: 2rem;
}

.error-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 2rem;
  padding-bottom: 1rem;
  border-bottom: 2px solid #e0e0e0;
}

.error-class {
  font-size: 1.5rem;
  font-weight: 600;
  margin-bottom: 0.5rem;
}

.error-meta {
  color: #666;
  font-size: 0.9rem;
}

.header-actions {
  display: flex;
  gap: 0.5rem;
}

.nav-btn {
  padding: 0.5rem 1rem;
  border: 1px solid #ddd;
  background-color: white;
  border-radius: 4px;
  cursor: pointer;
}

.nav-btn:hover {
  background-color: #f5f5f5;
}

.error-content {
  display: grid;
  grid-template-columns: 1fr 300px;
  gap: 2rem;
}

.tabs {
  display: flex;
  gap: 0.5rem;
  border-bottom: 2px solid #e0e0e0;
  margin-bottom: 1rem;
}

.tab-btn {
  padding: 0.75rem 1rem;
  border: none;
  background: none;
  cursor: pointer;
  border-bottom: 2px solid transparent;
  margin-bottom: -2px;
  font-weight: 500;
}

.tab-btn.active {
  border-bottom-color: #3498db;
  color: #3498db;
}

.tab-panel {
  padding: 1rem 0;
}

.summary-section {
  display: flex;
  flex-direction: column;
  gap: 2rem;
}

.message-block {
  background-color: #f5f5f5;
  padding: 1rem;
  border-radius: 4px;
  overflow-x: auto;
  font-family: 'Monaco', 'Courier New', monospace;
}

.tags-list {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.tag {
  background-color: #e8f4f8;
  color: #2980b9;
  padding: 0.25rem 0.75rem;
  border-radius: 12px;
  font-size: 0.85rem;
}

.add-tag-btn {
  background: none;
  border: 1px dashed #ddd;
  padding: 0.25rem 0.75rem;
  border-radius: 12px;
  cursor: pointer;
  color: #666;
}

.comment-form {
  margin-bottom: 2rem;
}

.comment-input {
  width: 100%;
  min-height: 100px;
  padding: 0.75rem;
  border: 1px solid #ddd;
  border-radius: 4px;
  margin-bottom: 0.5rem;
}

.comments-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.comment-item {
  border: 1px solid #e0e0e0;
  border-radius: 4px;
  padding: 1rem;
}

.comment-header {
  display: flex;
  justify-content: space-between;
  margin-bottom: 0.5rem;
  font-size: 0.85rem;
  color: #666;
}

.error-sidebar {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.sidebar-widget {
  background-color: #f9f9f9;
  border: 1px solid #e0e0e0;
  border-radius: 4px;
  padding: 1rem;
}

.sidebar-widget h3 {
  font-size: 0.9rem;
  color: #666;
  margin-bottom: 0.5rem;
}

.stat-value {
  font-size: 1.5rem;
  font-weight: 600;
}

.action-bar {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.action-btn {
  padding: 0.75rem;
  border: 1px solid #ddd;
  background-color: white;
  border-radius: 4px;
  cursor: pointer;
  text-align: left;
}

.action-btn:hover {
  background-color: #f5f5f5;
}

.loading {
  text-align: center;
  padding: 3rem;
  color: #666;
}
</style>

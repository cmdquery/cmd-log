<template>
  <div class="error-detail-page" v-if="fault">
    <!-- Header -->
    <div class="detail-header">
      <div>
        <h1 class="detail-title">{{ fault.error_class }}</h1>
        <div class="detail-subtitle">
          <span class="text-muted">Last seen {{ formatTime(fault.last_seen_at) }}</span>
          <span class="mx-2 text-muted">•</span>
          <span class="env-badge" :class="`env-${fault.environment}`">
            {{ fault.environment }}
          </span>
        </div>
      </div>
      <div class="detail-actions">
        <button class="btn btn--ghost btn--sm" @click="navigateOccurrence('first')">First</button>
        <button class="btn btn--ghost btn--sm" @click="navigateOccurrence('prev')">← Prev</button>
        <button class="btn btn--ghost btn--sm" @click="navigateOccurrence('next')">Next →</button>
        <button class="btn btn--ghost btn--sm" @click="navigateOccurrence('last')">Last</button>
      </div>
    </div>

    <div class="flex gap-6">
      <!-- Main Content -->
      <div class="flex-1">
        <!-- Tabs -->
        <div class="tabs">
          <button
            v-for="tab in tabs"
            :key="tab.key"
            :class="['tab', { 'is-active': activeTab === tab.key }]"
            @click="activeTab = tab.key"
          >
            {{ tab.label }}
          </button>
        </div>

        <!-- Tab Content -->
        <div class="tab-content">
          <!-- Summary Tab -->
          <div v-if="activeTab === 'summary'" class="tab-panel">
            <div class="flex flex-col gap-6">
              <!-- Status -->
              <div class="detail-item">
                <div class="detail-label">Status</div>
                <div class="flex items-center gap-3">
                  <StatusToggle
                    v-model="fault.resolved"
                    @update:model-value="updateResolved"
                  />
                  <span class="text-body-sm">
                    {{ fault.resolved ? 'Resolved' : 'Unresolved' }}
                  </span>
                </div>
              </div>
              
              <!-- Message -->
              <div class="card">
                <div class="card__header">
                  <h3 class="h5">Message</h3>
                </div>
                <div class="code-block">
                  <div class="code-block__content">
                    <pre>{{ fault.message }}</pre>
                  </div>
                </div>
              </div>

              <!-- Backtrace -->
              <div v-if="currentNotice && currentNotice.backtrace" class="card">
                <div class="card__header">
                  <h3 class="h5">Backtrace</h3>
                </div>
                <BacktraceViewer :backtrace="currentNotice.backtrace" />
              </div>

              <!-- Tags -->
              <div class="card">
                <div class="card__header">
                  <h3 class="h5">Tags</h3>
                </div>
                <div class="badge-group">
                  <span v-for="tag in fault.tags" :key="tag" class="badge">
                    {{ tag }}
                  </span>
                  <button class="btn btn--ghost btn--sm" @click="showAddTag = true">
                    + Add Tag
                  </button>
                </div>
              </div>
            </div>
          </div>

          <!-- Comments Tab -->
          <div v-if="activeTab === 'comments'" class="tab-panel">
            <div class="card mb-6">
              <div class="form-group">
                <textarea
                  v-model="newComment"
                  placeholder="Add a comment..."
                  class="form-textarea"
                  rows="3"
                ></textarea>
              </div>
              <button @click="addComment" class="btn btn--brand">Add Comment</button>
            </div>
            
            <div class="flex flex-col gap-4">
              <div v-for="comment in comments" :key="comment.id" class="card">
                <div class="flex justify-between mb-2">
                  <span class="text-body-sm font-medium">{{ comment.user?.name || 'Unknown' }}</span>
                  <span class="text-caption">{{ formatTime(comment.created_at) }}</span>
                </div>
                <p class="text-body-sm">{{ comment.comment }}</p>
              </div>
              <div v-if="comments.length === 0" class="card card--empty">
                <div class="card__text">No comments yet</div>
              </div>
            </div>
          </div>

          <!-- Backtrace Tab -->
          <div v-if="activeTab === 'backtrace'" class="tab-panel">
            <BacktraceViewer :backtrace="currentNotice?.backtrace || []" />
          </div>

          <!-- Context Tab -->
          <div v-if="activeTab === 'context'" class="tab-panel">
            <div class="card">
              <div class="card__header">
                <h3 class="h5">Custom Context</h3>
              </div>
              <div class="code-block" v-if="currentNotice && currentNotice.context">
                <div class="code-block__content">
                  <pre>{{ JSON.stringify(currentNotice.context, null, 2) }}</pre>
                </div>
              </div>
              <div v-else class="card__body text-muted">No context data available</div>
            </div>
          </div>

          <!-- Breadcrumbs Tab -->
          <div v-if="activeTab === 'breadcrumbs'" class="tab-panel">
            <BreadcrumbViewer :breadcrumbs="currentNotice?.breadcrumbs || []" />
          </div>

          <!-- Environment Tab -->
          <div v-if="activeTab === 'environment'" class="tab-panel">
            <div class="card">
              <div class="card__header">
                <h3 class="h5">Application Environment</h3>
              </div>
              <div class="code-block" v-if="currentNotice && currentNotice.environment">
                <div class="code-block__content">
                  <pre>{{ JSON.stringify(currentNotice.environment, null, 2) }}</pre>
                </div>
              </div>
              <div v-else class="card__body text-muted">No environment data available</div>
            </div>
          </div>

          <!-- History Tab -->
          <div v-if="activeTab === 'history'" class="tab-panel">
            <div class="card">
              <div class="flex flex-col">
                <div 
                  v-for="entry in history" 
                  :key="entry.id" 
                  class="flex items-center justify-between py-3 border-b border-primary"
                  style="border-color: var(--border-primary)"
                >
                  <div class="flex items-center gap-3">
                    <span class="badge badge--xs">{{ entry.action }}</span>
                    <span v-if="entry.user" class="text-body-sm">
                      {{ entry.user.name || entry.user.email }}
                    </span>
                  </div>
                  <span class="text-caption">{{ formatTime(entry.created_at) }}</span>
                </div>
                <div v-if="history.length === 0" class="py-6 text-center text-muted">
                  No history available
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Sidebar -->
      <div class="w-80 flex-shrink-0">
        <div class="flex flex-col gap-4">
          <!-- Stats -->
          <div class="card">
            <div class="detail-label mb-2">Total Occurrences</div>
            <div class="metric-card__value">{{ stats?.total_occurrences || 0 }}</div>
          </div>

          <div class="card">
            <div class="detail-label mb-2">Last Occurred</div>
            <div class="text-body">{{ formatTime(stats?.last_occurred) || '—' }}</div>
          </div>

          <div class="card">
            <div class="detail-label mb-2">First Occurred</div>
            <div class="text-body">{{ formatTime(stats?.first_occurred) || '—' }}</div>
          </div>

          <!-- Actions -->
          <div class="card">
            <div class="detail-label mb-3">Actions</div>
            <div class="flex flex-col gap-2">
              <button class="btn btn--secondary btn--sm w-full" @click="assignFault">
                Assign
              </button>
              <button class="btn btn--secondary btn--sm w-full" @click="ignoreFault">
                Ignore
              </button>
              <button class="btn btn--secondary btn--sm w-full" @click="exportFault">
                Export
              </button>
              <button class="btn btn--danger btn--sm w-full" @click="deleteFault">
                Delete
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
  
  <div v-else class="loading-spinner">
    <div class="spinner"></div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
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
    await fetchWithAuth(`/api/v1/faults/${fault.value.id}/comments`, {
      method: 'POST',
      body: JSON.stringify({
        comment: newComment.value,
        user_id: 1
      })
    })
    newComment.value = ''
    await loadFault()
  } catch (error) {
    console.error('Error adding comment:', error)
  }
}

const assignFault = async () => {
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

<style>
.w-80 {
  width: 20rem;
}

.font-medium {
  font-weight: var(--weight-medium);
}

.border-b {
  border-bottom-width: 1px;
  border-bottom-style: solid;
}

.tab-panel {
  padding-top: var(--space-4);
}

.tab-content {
  min-height: 400px;
}
</style>

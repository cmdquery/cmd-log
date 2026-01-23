const API_BASE = ''

// Helper function to get cookie value by name
function getCookie(name) {
  try {
    if (!document.cookie) {
      return null
    }
    const value = `; ${document.cookie}`
    const parts = value.split(`; ${name}=`)
    if (parts.length === 2) {
      const cookieValue = parts.pop().split(';').shift()
      // Return null for empty strings
      return cookieValue && cookieValue.trim() ? cookieValue.trim() : null
    }
    return null
  } catch (error) {
    console.error('Error reading cookie:', error)
    return null
  }
}

// Valid API key values - reject invalid ones like "authenticated"
const INVALID_API_KEY_VALUES = ['authenticated', 'true', 'false', '']

function isValidApiKey(value) {
  if (!value || typeof value !== 'string') {
    return false
  }
  const trimmed = value.trim()
  return trimmed.length > 0 && !INVALID_API_KEY_VALUES.includes(trimmed.toLowerCase())
}

// Get API key from localStorage, cookie, or query parameter
function getApiKey() {
  // First check query parameter
  const urlParams = new URLSearchParams(window.location.search)
  const queryKey = urlParams.get('api_key')
  if (queryKey && isValidApiKey(queryKey)) {
    localStorage.setItem('admin_api_key', queryKey.trim())
    return queryKey.trim()
  }
  
  // Then check localStorage
  const storedKey = localStorage.getItem('admin_api_key')
  if (storedKey) {
    if (isValidApiKey(storedKey)) {
      return storedKey.trim()
    } else {
      // Clear invalid value from localStorage
      console.warn('Invalid API key value found in localStorage, clearing it')
      localStorage.removeItem('admin_api_key')
    }
  }
  
  // Finally check cookie (backend sets admin_api_key cookie on login)
  const cookieKey = getCookie('admin_api_key')
  if (cookieKey && isValidApiKey(cookieKey)) {
    // Also store in localStorage for consistency
    localStorage.setItem('admin_api_key', cookieKey)
    return cookieKey
  }
  
  return null
}

// Set API key
function setApiKey(key) {
  localStorage.setItem('admin_api_key', key)
}

// Remove API key
function removeApiKey() {
  localStorage.removeItem('admin_api_key')
}

// Make authenticated fetch request
async function fetchWithAuth(url, options = {}) {
  const apiKey = getApiKey()
  if (apiKey) {
    if (!options.headers) {
      options.headers = {}
    }
    options.headers['X-API-Key'] = apiKey
  }
  
  const response = await fetch(`${API_BASE}${url}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...options.headers
    }
  })
  
  if (!response.ok) {
    // Check content-type before attempting to parse JSON
    const contentType = response.headers.get('content-type') || ''
    let error = { error: `Request failed with status ${response.status}` }
    
    if (contentType.includes('application/json')) {
      try {
        const errorData = await response.json()
        error = errorData
      } catch (parseError) {
        console.error('Failed to parse error response as JSON:', parseError)
        // Try to get text response as fallback
        try {
          const text = await response.text()
          console.error('Error response body:', text)
          error = { error: `Server error (${response.status}): ${text.substring(0, 200)}` }
        } catch (textError) {
          console.error('Failed to read error response:', textError)
          error = { error: `Request failed with status ${response.status}` }
        }
      }
    } else {
      // Non-JSON response (likely HTML error page)
      try {
        const text = await response.text()
        console.error('Non-JSON error response:', text.substring(0, 500))
        error = { 
          error: `Server returned ${contentType || 'non-JSON'} response (${response.status})`,
          details: text.substring(0, 200)
        }
      } catch (textError) {
        console.error('Failed to read error response:', textError)
        error = { error: `Request failed with status ${response.status}` }
      }
    }
    
    // Include details in error message if available
    const errorMessage = error.error || error.details || `Request failed with status ${response.status}`
    const fullError = error.details && error.error ? `${error.error}: ${error.details}` : errorMessage
    throw new Error(fullError)
  }
  
  // Parse successful response
  const contentType = response.headers.get('content-type') || ''
  if (contentType.includes('application/json')) {
    try {
      return await response.json()
    } catch (parseError) {
      console.error('Failed to parse successful response as JSON:', parseError)
      throw new Error('Server returned invalid JSON response')
    }
  } else {
    // Non-JSON successful response (unexpected but handle gracefully)
    // This usually means authentication failed and server returned HTML error page
    const text = await response.text()
    console.warn('Non-JSON response received:', contentType)
    console.warn('Response body preview:', text.substring(0, 500))
    
    // Check if it's an HTML error page (likely authentication issue)
    if (contentType.includes('text/html')) {
      throw new Error('Server returned HTML instead of JSON. This may indicate an authentication issue. Please check your API key.')
    }
    
    throw new Error(`Server returned ${contentType || 'non-JSON'} response instead of JSON`)
  }
}

// Health check
export async function getHealth() {
  return fetchWithAuth('/admin/health?format=json')
}

// Get metrics
export async function getMetrics(range = '24h', interval = '5m') {
  return fetchWithAuth(`/admin/metrics?range=${range}&interval=${interval}`)
}

// Get recent logs
export async function getRecentLogs(limit = 100) {
  return fetchWithAuth(`/admin/logs/recent?limit=${limit}`)
}

// Get log by ID
export async function getLogById(id) {
  return fetchWithAuth(`/admin/logs/${id}`)
}

// Get stats
export async function getStats(range = '24h') {
  return fetchWithAuth(`/admin/stats?range=${range}`)
}

// List API keys
export async function listAPIKeys() {
  return fetchWithAuth('/admin/api/keys')
}

// Create API key
export async function createAPIKey(name, description = '') {
  return fetchWithAuth('/admin/api/keys', {
    method: 'POST',
    body: JSON.stringify({ name, description })
  })
}

// Delete API key
export async function deleteAPIKey(id) {
  return fetchWithAuth(`/admin/api/keys/${id}`, {
    method: 'DELETE'
  })
}

// Login (sets cookie, handled by backend)
export async function login(password) {
  const response = await fetch(`${API_BASE}/admin/login`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ password })
  })
  
  if (response.ok) {
    const data = await response.json()
    return data
  }
  
  const error = await response.json().catch(() => ({ error: 'Login failed' }))
  return { success: false, error: error.error || 'Invalid password' }
}

export { getApiKey, setApiKey, removeApiKey, getCookie, fetchWithAuth }


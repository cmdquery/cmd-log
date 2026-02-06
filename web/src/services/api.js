const API_BASE = ''

// Get auth token from localStorage
function getAuthToken() {
  const token = localStorage.getItem('auth_token')
  if (token && token.trim().length > 0) {
    return token.trim()
  }
  return null
}

// Set auth token in localStorage
function setAuthToken(token) {
  localStorage.setItem('auth_token', token)
}

// Remove auth token (logout)
function removeAuthToken() {
  localStorage.removeItem('auth_token')
  localStorage.removeItem('user_info')
  // Also clear the cookie
  document.cookie = 'auth_token=; Max-Age=0; path=/'
}

// Get stored user info
function getUserInfo() {
  try {
    const info = localStorage.getItem('user_info')
    return info ? JSON.parse(info) : null
  } catch {
    return null
  }
}

// Check if current user is an admin
function isAdmin() {
  const user = getUserInfo()
  return user ? !!user.is_admin : false
}

// Check if user is authenticated
function isAuthenticated() {
  return !!getAuthToken()
}

// Make authenticated fetch request
async function fetchWithAuth(url, options = {}) {
  const token = getAuthToken()
  if (!options.headers) {
    options.headers = {}
  }
  if (token) {
    options.headers['Authorization'] = `Bearer ${token}`
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
    // If we get a 401, token may be expired
    if (response.status === 401) {
      removeAuthToken()
    }

    const contentType = response.headers.get('content-type') || ''
    let error = { error: `Request failed with status ${response.status}` }

    if (contentType.includes('application/json')) {
      try {
        const errorData = await response.json()
        error = errorData
      } catch (parseError) {
        console.error('Failed to parse error response as JSON:', parseError)
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
    const text = await response.text()
    console.warn('Non-JSON response received:', contentType)
    console.warn('Response body preview:', text.substring(0, 500))

    if (contentType.includes('text/html')) {
      throw new Error('Server returned HTML instead of JSON. This may indicate an authentication issue.')
    }

    throw new Error(`Server returned ${contentType || 'non-JSON'} response instead of JSON`)
  }
}

// Auth: Register
export async function register(name, email, password) {
  const response = await fetch(`${API_BASE}/auth/register`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    },
    body: JSON.stringify({ name, email, password })
  })

  const data = await response.json()
  if (!response.ok) {
    return { success: false, error: data.error || 'Registration failed' }
  }
  return data
}

// Auth: Login
export async function login(email, password) {
  const response = await fetch(`${API_BASE}/auth/login`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    },
    body: JSON.stringify({ email, password })
  })

  const data = await response.json()
  if (response.ok && data.token) {
    setAuthToken(data.token)
    if (data.user) {
      localStorage.setItem('user_info', JSON.stringify(data.user))
    }
    return data
  }

  return { success: false, error: data.error || 'Login failed' }
}

// Auth: Logout
export function logout() {
  removeAuthToken()
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

export { getAuthToken, setAuthToken, removeAuthToken, isAuthenticated, isAdmin, getUserInfo, fetchWithAuth }

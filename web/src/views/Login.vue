<template>
  <div class="login-page">
    <div class="login-card">
      <h2>Admin Login</h2>
      <form @submit.prevent="handleLogin">
        <div class="form-group">
          <label for="password">Password</label>
          <input
            type="password"
            id="password"
            v-model="password"
            required
            placeholder="Enter admin password"
          />
        </div>
        <div v-if="error" class="error-message">{{ error }}</div>
        <button type="submit" class="btn btn-primary" :disabled="loading">
          {{ loading ? 'Logging in...' : 'Login' }}
        </button>
      </form>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { login, setApiKey, getCookie } from '../services/api'

const router = useRouter()
const password = ref('')
const error = ref('')
const loading = ref(false)

const handleLogin = async () => {
  error.value = ''
  loading.value = true
  
  try {
    const result = await login(password.value)
    if (result.success) {
      // Read the actual API key from the cookie set by the backend
      // Give it a small delay to ensure the cookie is set
      await new Promise(resolve => setTimeout(resolve, 100))
      const apiKey = getCookie('admin_api_key')
      
      if (apiKey) {
        // Store the actual API key value from the cookie
        setApiKey(apiKey)
      } else {
        // Fallback to 'thuglife' if cookie reading fails (backend sets this value)
        console.warn('Could not read cookie, using fallback API key')
        setApiKey('thuglife')
      }
      
      router.push('/admin')
    } else {
      error.value = result.error || 'Invalid password'
    }
  } catch (err) {
    error.value = err.message || 'Login failed'
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.login-page {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 80vh;
}

.login-card {
  background: white;
  padding: 3rem;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
  width: 100%;
  max-width: 400px;
}

.login-card h2 {
  margin-bottom: 2rem;
  color: #2c3e50;
  text-align: center;
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

.form-group input {
  width: 100%;
  padding: 0.75rem;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 1rem;
  font-family: inherit;
}

.form-group input:focus {
  outline: none;
  border-color: #3498db;
}

.btn {
  width: 100%;
  padding: 0.75rem;
  font-size: 1rem;
}

.error-message {
  background-color: #fee;
  color: #721c24;
  padding: 0.75rem;
  border-radius: 4px;
  margin-bottom: 1rem;
}
</style>


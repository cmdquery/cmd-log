<template>
  <div class="layout-auth">
    <div class="login-container">
      <div class="login-card">
        <div class="login-header">
          <img src="/logo.svg" alt="Logo" class="login-logo" />
          <h1 class="login-title">cmd log</h1>
          <p class="login-subtitle">Sign in to your account</p>
        </div>
        
        <form @submit.prevent="handleLogin">
          <div class="form-group">
            <label class="form-label" for="password">Password</label>
            <input
              type="password"
              id="password"
              class="form-input"
              v-model="password"
              required
              placeholder="Enter admin password"
            />
          </div>
          
          <div v-if="error" class="alert alert--error mb-4">
            {{ error }}
          </div>
          
          <button type="submit" class="btn btn--brand btn--block" :disabled="loading">
            {{ loading ? 'Signing in...' : 'Sign in' }}
          </button>
        </form>
      </div>
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
      await new Promise(resolve => setTimeout(resolve, 100))
      const apiKey = getCookie('admin_api_key')
      
      if (apiKey) {
        setApiKey(apiKey)
      } else {
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

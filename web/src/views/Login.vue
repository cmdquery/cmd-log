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
            <label class="form-label" for="email">Email</label>
            <input
              type="email"
              id="email"
              class="form-input"
              v-model="email"
              required
              placeholder="you@example.com"
              autocomplete="email"
            />
          </div>

          <div class="form-group">
            <label class="form-label" for="password">Password</label>
            <input
              type="password"
              id="password"
              class="form-input"
              v-model="password"
              required
              placeholder="Enter your password"
              autocomplete="current-password"
            />
          </div>
          
          <div v-if="error" class="alert alert--error mb-4">
            {{ error }}
          </div>
          
          <button type="submit" class="btn btn--brand btn--block" :disabled="loading">
            {{ loading ? 'Signing in...' : 'Sign in' }}
          </button>
        </form>

        <p class="login-footer">
          Don't have an account? <router-link to="/register">Create one</router-link>
        </p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { login } from '../services/api'

const router = useRouter()
const email = ref('')
const password = ref('')
const error = ref('')
const loading = ref(false)

const handleLogin = async () => {
  error.value = ''
  loading.value = true
  
  try {
    const result = await login(email.value, password.value)
    if (result.success) {
      router.push('/errors')
    } else {
      error.value = result.error || 'Invalid email or password'
    }
  } catch (err) {
    error.value = err.message || 'Login failed'
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.login-footer {
  text-align: center;
  margin-top: var(--space-6);
  font-size: var(--text-small);
  color: var(--text-tertiary);
}

.login-footer a {
  color: var(--color-brand);
  text-decoration: none;
}

.login-footer a:hover {
  text-decoration: underline;
}
</style>

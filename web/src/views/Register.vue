<template>
  <div class="layout-auth">
    <div class="login-container">
      <div class="login-card">
        <div class="login-header">
          <img src="/logo.svg" alt="Logo" class="login-logo" />
          <h1 class="login-title">cmd log</h1>
          <p class="login-subtitle">Create your account</p>
        </div>
        
        <form @submit.prevent="handleRegister">
          <div class="form-group">
            <label class="form-label" for="name">Name</label>
            <input
              type="text"
              id="name"
              class="form-input"
              v-model="name"
              required
              placeholder="Your name"
              autocomplete="name"
            />
          </div>

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
              placeholder="At least 6 characters"
              autocomplete="new-password"
            />
          </div>

          <div class="form-group">
            <label class="form-label" for="confirmPassword">Confirm Password</label>
            <input
              type="password"
              id="confirmPassword"
              class="form-input"
              v-model="confirmPassword"
              required
              placeholder="Repeat your password"
              autocomplete="new-password"
            />
          </div>
          
          <div v-if="error" class="alert alert--error mb-4">
            {{ error }}
          </div>

          <div v-if="success" class="alert alert--success mb-4">
            {{ success }}
          </div>
          
          <button type="submit" class="btn btn--brand btn--block" :disabled="loading">
            {{ loading ? 'Creating account...' : 'Create account' }}
          </button>
        </form>

        <p class="register-footer">
          Already have an account? <router-link to="/login">Sign in</router-link>
        </p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { register } from '../services/api'

const router = useRouter()
const name = ref('')
const email = ref('')
const password = ref('')
const confirmPassword = ref('')
const error = ref('')
const success = ref('')
const loading = ref(false)

const handleRegister = async () => {
  error.value = ''
  success.value = ''

  if (password.value !== confirmPassword.value) {
    error.value = 'Passwords do not match'
    return
  }

  if (password.value.length < 6) {
    error.value = 'Password must be at least 6 characters'
    return
  }

  loading.value = true
  
  try {
    const result = await register(name.value, email.value, password.value)
    if (result.success) {
      success.value = 'Account created successfully! Redirecting to login...'
      setTimeout(() => {
        router.push('/login')
      }, 1500)
    } else {
      error.value = result.error || 'Registration failed'
    }
  } catch (err) {
    error.value = err.message || 'Registration failed'
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.register-footer {
  text-align: center;
  margin-top: var(--space-6);
  font-size: var(--text-small);
  color: var(--text-tertiary);
}

.register-footer a {
  color: var(--color-brand);
  text-decoration: none;
}

.register-footer a:hover {
  text-decoration: underline;
}

.alert--success {
  background-color: rgba(52, 211, 153, 0.1);
  border: 1px solid rgba(52, 211, 153, 0.3);
  color: rgb(52, 211, 153);
  padding: var(--space-3) var(--space-4);
  border-radius: var(--radius-md);
  font-size: var(--text-small);
}
</style>

<template>
  <div id="app" :class="{ 'dark': isDark }">
    <!-- Header Navigation -->
    <header class="app-header" v-if="showNav">
      <div class="header-left">
        <button class="sidebar-toggle" @click="sidebarOpen = !sidebarOpen">
          <span>☰</span>
        </button>
        <div class="logo">
          <img src="/logo.svg" alt="Logo" class="logo-img" v-if="!isDark" />
          <img src="/logo-white.svg" alt="Logo" class="logo-img" v-else />
          <span class="logo-text">cmd log</span>
        </div>
        <div class="breadcrumb md:flex hidden">
          <span class="breadcrumb-item">Projects</span>
          <span class="breadcrumb-separator">/</span>
          <span class="breadcrumb-item active">Default</span>
        </div>
      </div>
      <div class="header-right">
        <button class="header-icon" title="Notifications">
          🔔
        </button>
        <div class="user-menu">
          <button class="user-avatar">U</button>
        </div>
      </div>
    </header>

    <!-- Sidebar Navigation -->
    <aside class="sidebar" :class="{ 'sidebar-open': sidebarOpen }" v-if="showNav">
      <nav class="sidebar-nav">
        <router-link to="/errors" class="nav-item">
          <span class="nav-icon">⚡</span>
          <span class="nav-text">Errors</span>
        </router-link>
        <router-link to="/logs" class="nav-item">
          <span class="nav-icon">📋</span>
          <span class="nav-text">Logs</span>
        </router-link>
        <router-link to="/dashboard" class="nav-item">
          <span class="nav-icon">📊</span>
          <span class="nav-text">Dashboard</span>
        </router-link>
        <router-link to="/health" class="nav-item">
          <span class="nav-icon">💚</span>
          <span class="nav-text">Health</span>
        </router-link>
        <router-link to="/api-keys" class="nav-item">
          <span class="nav-icon">🔑</span>
          <span class="nav-text">API Keys</span>
        </router-link>
        <div class="nav-item opacity-50 cursor-not-allowed">
          <span class="nav-icon">🔔</span>
          <span class="nav-text">Alarms</span>
        </div>
        <div class="nav-item opacity-50 cursor-not-allowed">
          <span class="nav-icon">☁️</span>
          <span class="nav-text">Uptime</span>
        </div>
        <div class="nav-item opacity-50 cursor-not-allowed">
          <span class="nav-icon">⊕</span>
          <span class="nav-text">Deployments</span>
        </div>
        <div class="nav-item opacity-50 cursor-not-allowed">
          <span class="nav-icon">📄</span>
          <span class="nav-text">Reports</span>
        </div>
        <div class="nav-item opacity-50 cursor-not-allowed">
          <span class="nav-icon">⚙️</span>
          <span class="nav-text">Settings</span>
        </div>
      </nav>
      <div class="sidebar-footer">
        <a href="#" class="footer-link">Documentation</a>
        <a href="#" class="footer-link">Support</a>
        <a href="#" class="footer-link">Status</a>
      </div>
      <div class="theme-toggle">
        <button @click="toggleTheme" class="theme-btn">
          {{ isDark ? '☀️' : '🌙' }}
        </button>
      </div>
    </aside>

    <!-- Overlay for mobile -->
    <div 
      class="sidebar-overlay" 
      :class="{ 'show': sidebarOpen }" 
      v-if="sidebarOpen && showNav" 
      @click="sidebarOpen = false"
    ></div>

    <!-- Main Content -->
    <main :class="['main-content', { 'main-content-with-sidebar': showNav }]">
      <router-view />
    </main>

    <Notification 
      v-if="notification.message" 
      :message="notification.message" 
      :type="notification.type" 
      @close="notification.message = ''" 
    />
  </div>
</template>

<script setup>
import { computed, ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import Notification from './components/Notification.vue'

const route = useRoute()
const sidebarOpen = ref(false)
const isDark = ref(true) // Default to dark mode

const showNav = computed(() => {
  return route.path !== '/admin/login' && route.path !== '/login'
})

const toggleTheme = () => {
  isDark.value = !isDark.value
  localStorage.setItem('theme', isDark.value ? 'dark' : 'light')
  updateTheme()
}

const updateTheme = () => {
  if (isDark.value) {
    document.documentElement.classList.add('dark')
  } else {
    document.documentElement.classList.remove('dark')
  }
}

onMounted(() => {
  const savedTheme = localStorage.getItem('theme')
  if (savedTheme === 'light') {
    isDark.value = false
  } else {
    isDark.value = true // Default to dark
  }
  updateTheme()
})

const notification = ref({
  message: '',
  type: 'info'
})
</script>

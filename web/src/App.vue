<template>
  <div id="app" :class="{ 'dark-theme': isDark }">
    <!-- Header Navigation -->
    <header class="app-header" v-if="showNav">
      <div class="header-left">
        <button class="sidebar-toggle" @click="sidebarOpen = !sidebarOpen">
          <span>☰</span>
        </button>
        <div class="logo">
          <img src="/logo.png" alt="Logo" class="logo-img" />
          <span class="logo-text">cmd log</span>
        </div>
        <div class="breadcrumb">
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
        <router-link to="/insights" class="nav-item" disabled>
          <span class="nav-icon">🔍</span>
          <span class="nav-text">Insights</span>
        </router-link>
        <router-link to="/dashboards" class="nav-item" disabled>
          <span class="nav-icon">📊</span>
          <span class="nav-text">Dashboards</span>
        </router-link>
        <router-link to="/alarms" class="nav-item" disabled>
          <span class="nav-icon">🔔</span>
          <span class="nav-text">Alarms</span>
        </router-link>
        <router-link to="/uptime" class="nav-item" disabled>
          <span class="nav-icon">☁️</span>
          <span class="nav-text">Uptime</span>
        </router-link>
        <router-link to="/check-ins" class="nav-item" disabled>
          <span class="nav-icon">✓</span>
          <span class="nav-text">Check-Ins</span>
        </router-link>
        <router-link to="/deployments" class="nav-item" disabled>
          <span class="nav-icon">⊕</span>
          <span class="nav-text">Deployments</span>
        </router-link>
        <router-link to="/reports" class="nav-item" disabled>
          <span class="nav-icon">📄</span>
          <span class="nav-text">Reports</span>
        </router-link>
        <router-link to="/settings" class="nav-item" disabled>
          <span class="nav-icon">⚙️</span>
          <span class="nav-text">Settings</span>
        </router-link>
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
    <div class="sidebar-overlay" v-if="sidebarOpen && showNav" @click="sidebarOpen = false"></div>

    <!-- Main Content -->
    <main :class="['main-content', { 'main-content-with-sidebar': showNav }]">
      <router-view />
    </main>

    <Notification v-if="notification.message" :message="notification.message" :type="notification.type" @close="notification.message = ''" />
  </div>
</template>

<script setup>
import { computed, ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import Notification from './components/Notification.vue'

const route = useRoute()
const sidebarOpen = ref(false)
const isDark = ref(false)

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
  if (savedTheme === 'dark') {
    isDark.value = true
  }
  updateTheme()
})

const notification = ref({
  message: '',
  type: 'info'
})
</script>

<style scoped>
#app {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  background-color: #f5f5f5;
  transition: background-color 0.3s;
}

#app.dark-theme {
  background-color: #1a1a1a;
  color: #ffffff;
}

.app-header {
  height: 60px;
  background-color: #ffffff;
  border-bottom: 1px solid #e0e0e0;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 1rem;
  position: sticky;
  top: 0;
  z-index: 100;
  box-shadow: 0 1px 3px rgba(0,0,0,0.1);
}

.dark-theme .app-header {
  background-color: #2a2a2a;
  border-bottom-color: #404040;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.sidebar-toggle {
  background: none;
  border: none;
  font-size: 1.5rem;
  cursor: pointer;
  padding: 0.5rem;
  display: none;
}

.logo {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.logo-img {
  height: 32px;
  width: auto;
}

.logo-text {
  font-weight: 600;
  font-size: 1.2rem;
}

.breadcrumb {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-left: 1rem;
  color: #666;
}

.breadcrumb-separator {
  color: #999;
}

.breadcrumb-item.active {
  color: #333;
  font-weight: 500;
}

.dark-theme .breadcrumb-item.active {
  color: #fff;
}

.header-right {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.header-icon {
  background: none;
  border: none;
  font-size: 1.2rem;
  cursor: pointer;
  padding: 0.5rem;
}

.user-avatar {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  background-color: #3498db;
  color: white;
  border: none;
  cursor: pointer;
  font-weight: 600;
}

.sidebar {
  width: 240px;
  background-color: #ffffff;
  border-right: 1px solid #e0e0e0;
  position: fixed;
  left: 0;
  top: 60px;
  bottom: 0;
  overflow-y: auto;
  z-index: 90;
  transition: transform 0.3s;
}

.dark-theme .sidebar {
  background-color: #2a2a2a;
  border-right-color: #404040;
}

.sidebar-nav {
  padding: 1rem 0;
}

.nav-item {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.75rem 1.5rem;
  color: #666;
  text-decoration: none;
  transition: background-color 0.2s;
}

.nav-item:hover {
  background-color: #f5f5f5;
}

.dark-theme .nav-item:hover {
  background-color: #333;
}

.nav-item.router-link-active {
  background-color: #f0f7ff;
  color: #3498db;
  font-weight: 500;
}

.dark-theme .nav-item.router-link-active {
  background-color: #1a2332;
  color: #5dade2;
}

.nav-icon {
  font-size: 1.2rem;
}

.nav-text {
  font-size: 0.95rem;
}

.sidebar-footer {
  padding: 1rem 1.5rem;
  border-top: 1px solid #e0e0e0;
  margin-top: auto;
}

.dark-theme .sidebar-footer {
  border-top-color: #404040;
}

.footer-link {
  display: block;
  color: #666;
  text-decoration: none;
  padding: 0.5rem 0;
  font-size: 0.85rem;
}

.footer-link:hover {
  color: #3498db;
}

.theme-toggle {
  padding: 1rem 1.5rem;
  border-top: 1px solid #e0e0e0;
}

.dark-theme .theme-toggle {
  border-top-color: #404040;
}

.theme-btn {
  background: none;
  border: none;
  font-size: 1.5rem;
  cursor: pointer;
  padding: 0.5rem;
}

.sidebar-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0,0,0,0.5);
  z-index: 85;
  display: none;
}

.main-content {
  flex: 1;
  padding: 2rem;
  margin-left: 0;
  transition: margin-left 0.3s;
}

.main-content-with-sidebar {
  margin-left: 240px;
}

@media (max-width: 768px) {
  .sidebar-toggle {
    display: block;
  }
  
  .sidebar {
    transform: translateX(-100%);
  }
  
  .sidebar.sidebar-open {
    transform: translateX(0);
  }
  
  .sidebar-overlay {
    display: block;
  }
  
  .main-content-with-sidebar {
    margin-left: 0;
  }
  
  .breadcrumb {
    display: none;
  }
}
</style>

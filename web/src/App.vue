<template>
  <div id="app">
    <nav class="navbar" v-if="showNav">
      <div class="nav-container">
        <div class="nav-brand">
          <img src="/logo.png" alt="Logo" class="nav-logo" />
          <h1 class="nav-title">cmd log</h1>
        </div>
        <ul class="nav-menu">
          <li><router-link to="/admin">Dashboard</router-link></li>
          <li><router-link to="/admin/logs">Logs</router-link></li>
          <li><router-link to="/admin/health">Health</router-link></li>
          <li><router-link to="/admin/api-keys">API Keys</router-link></li>
        </ul>
      </div>
    </nav>
    <main class="main-content">
      <router-view />
    </main>
    <Notification v-if="notification.message" :message="notification.message" :type="notification.type" @close="notification.message = ''" />
  </div>
</template>

<script setup>
import { computed, ref } from 'vue'
import { useRoute } from 'vue-router'
import Notification from './components/Notification.vue'

const route = useRoute()

const showNav = computed(() => {
  return route.path !== '/admin/login'
})

const notification = ref({
  message: '',
  type: 'info'
})
</script>


import { createRouter, createWebHistory } from 'vue-router'
import { getApiKey } from '../services/api'
import Dashboard from '../views/Dashboard.vue'
import LogsViewer from '../views/LogsViewer.vue'
import LogDetail from '../views/LogDetail.vue'
import HealthStatus from '../views/HealthStatus.vue'
import APIKeys from '../views/APIKeys.vue'
import Login from '../views/Login.vue'

const routes = [
  {
    path: '/',
    redirect: '/errors'
  },
  {
    path: '/login',
    name: 'Login',
    component: Login,
    meta: { requiresAuth: false }
  },
  {
    path: '/admin/login',
    name: 'AdminLogin',
    component: Login,
    meta: { requiresAuth: false }
  },
  {
    path: '/errors',
    name: 'Errors',
    component: () => import('../views/Errors.vue'),
    meta: { requiresAuth: true }
  },
  {
    path: '/errors/:id',
    name: 'ErrorDetail',
    component: () => import('../views/ErrorDetail.vue'),
    meta: { requiresAuth: true }
  },
  {
    path: '/admin',
    name: 'Dashboard',
    component: Dashboard,
    meta: { requiresAuth: true }
  },
  {
    path: '/admin/logs',
    name: 'Logs',
    component: LogsViewer,
    meta: { requiresAuth: true }
  },
  {
    path: '/admin/logs/:id',
    name: 'LogDetail',
    component: LogDetail,
    meta: { requiresAuth: true }
  },
  {
    path: '/admin/health',
    name: 'Health',
    component: HealthStatus,
    meta: { requiresAuth: true }
  },
  {
    path: '/admin/api-keys',
    name: 'APIKeys',
    component: APIKeys,
    meta: { requiresAuth: true }
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

// Navigation guard to check authentication
router.beforeEach((to, from, next) => {
  if (to.meta.requiresAuth) {
    const apiKey = getApiKey()
    if (!apiKey) {
      next('/login')
    } else {
      next()
    }
  } else {
    next()
  }
})

export default router


import { createRouter, createWebHistory } from 'vue-router'
import { isAuthenticated } from '../services/api'
import Dashboard from '../views/Dashboard.vue'
import LogsViewer from '../views/LogsViewer.vue'
import LogDetail from '../views/LogDetail.vue'
import HealthStatus from '../views/HealthStatus.vue'
import APIKeys from '../views/APIKeys.vue'
import Login from '../views/Login.vue'
import Register from '../views/Register.vue'

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
    path: '/register',
    name: 'Register',
    component: Register,
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
    path: '/dashboard',
    name: 'Dashboard',
    component: Dashboard,
    meta: { requiresAuth: true }
  },
  {
    path: '/admin',
    redirect: '/dashboard'
  },
  {
    path: '/logs',
    name: 'Logs',
    component: LogsViewer,
    meta: { requiresAuth: true }
  },
  {
    path: '/logs/:id',
    name: 'LogDetail',
    component: LogDetail,
    meta: { requiresAuth: true }
  },
  {
    path: '/admin/logs',
    redirect: '/logs'
  },
  {
    path: '/health',
    name: 'Health',
    component: HealthStatus,
    meta: { requiresAuth: true }
  },
  {
    path: '/admin/health',
    redirect: '/health'
  },
  {
    path: '/api-keys',
    name: 'APIKeys',
    component: APIKeys,
    meta: { requiresAuth: true }
  },
  {
    path: '/admin/api-keys',
    redirect: '/api-keys'
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

// Navigation guard to check authentication
router.beforeEach((to, from, next) => {
  if (to.meta.requiresAuth) {
    if (!isAuthenticated()) {
      next('/login')
    } else {
      next()
    }
  } else {
    next()
  }
})

export default router

import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { fileURLToPath, URL } from 'node:url'

// Plugin to handle SPA routing - serve index.html for routes that don't match API endpoints
function spaFallback() {
  return {
    name: 'spa-fallback',
    configureServer(server) {
      server.middlewares.use((req, res, next) => {
        // Skip Vite internal routes (HMR, client, etc.)
        if (req.url.startsWith('/@')) {
          return next()
        }
        
        // Skip Vite internal routes, source files, and static assets
        if (req.url.startsWith('/src/') || 
            req.url.startsWith('/assets') || 
            req.url.includes('.')) {
          return next()
        }
        
        // For API routes (/api/*), always proxy
        if (req.url.startsWith('/api/')) {
          return next()
        }
        
        // For admin routes (/admin/*), check if it's an API call
        if (req.url.startsWith('/admin/')) {
          // Non-GET requests to /admin/* should always be proxied
          if (req.method !== 'GET') {
            return next()
          }
          
          // For GET requests, check if it's an API call (wants JSON)
          // vs browser navigation (wants HTML)
          const wantsJSON = req.headers.accept?.includes('application/json')
          if (wantsJSON) {
            return next()  // Let proxy handle API calls
          }
          
          // Browser navigation to /admin/* routes should serve SPA
          // (the Vue router will handle the routing)
        }
        
        // For all other routes (frontend routes), serve index.html
        req.url = '/index.html'
        next()
      })
    }
  }
}

export default defineConfig({
  plugins: [vue(), spaFallback()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url))
    }
  },
  build: {
    outDir: 'dist',
    assetsDir: 'assets',
    sourcemap: false
  },
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://localhost:8080',
        changeOrigin: true
      },
      // Proxy API endpoints under /admin
      '/admin/login': {
        target: 'http://localhost:8080',
        changeOrigin: true
      },
      '/admin/health': {
        target: 'http://localhost:8080',
        changeOrigin: true
      },
      '/admin/metrics': {
        target: 'http://localhost:8080',
        changeOrigin: true
      },
      '/admin/logs/recent': {
        target: 'http://localhost:8080',
        changeOrigin: true
      },
      '/admin/logs': {
        target: 'http://localhost:8080',
        changeOrigin: true
      },
      '/admin/stats': {
        target: 'http://localhost:8080',
        changeOrigin: true
      },
      '/admin/api': {
        target: 'http://localhost:8080',
        changeOrigin: true
      }
    }
  }
})


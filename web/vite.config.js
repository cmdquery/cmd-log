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
        
        // Skip source files and static assets
        if (req.url.startsWith('/src/') || 
            req.url.startsWith('/api') || 
            req.url.startsWith('/assets') || 
            req.url.includes('.')) {
          return next()
        }
        
        // List of API endpoints that should be proxied (not served as SPA)
        const apiEndpoints = [
          '/admin/login',
          '/admin/health',
          '/admin/metrics',
          '/admin/logs/recent',
          '/admin/stats',
          '/admin/api/keys'
        ]
        
        // Check if this is an API endpoint
        const isApiEndpoint = apiEndpoints.some(endpoint => {
          if (req.method !== 'GET') {
            // POST, DELETE, PUT, etc. to API endpoints should be proxied
            return req.url.startsWith(endpoint)
          }
          // For GET requests, only proxy if it's explicitly a JSON request
          // (browser navigation will have text/html in Accept header)
          return req.url.startsWith(endpoint) && 
                 req.headers.accept?.includes('application/json')
        })
        
        // If it's an API endpoint, let the proxy handle it
        if (isApiEndpoint) {
          return next()
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


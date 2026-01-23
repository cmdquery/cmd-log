<template>
  <div class="backtrace-viewer">
    <div v-if="!backtrace || backtrace.length === 0" class="empty">
      No backtrace available
    </div>
    <div v-else class="backtrace-list">
      <div
        v-for="(frame, index) in backtrace"
        :key="index"
        class="backtrace-frame"
      >
        <div class="frame-header">
          <span class="frame-number">{{ index + 1 }}</span>
          <span class="frame-file" v-if="frame.file">
            {{ frame.file }}<span v-if="frame.line">:{{ frame.line }}</span>
          </span>
          <span class="frame-function" v-if="frame.function">
            in {{ frame.function }}
          </span>
        </div>
        <div class="frame-code" v-if="frame.code">
          <pre><code>{{ frame.code }}</code></pre>
        </div>
        <div class="frame-context" v-if="frame.context">
          <pre><code>{{ frame.context }}</code></pre>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
defineProps({
  backtrace: {
    type: Array,
    default: () => []
  }
})
</script>

<style scoped>
.backtrace-viewer {
  background-color: #ffffff;
  border: 1px solid #e0e0e0;
  border-radius: 4px;
  padding: 1rem;
}

.empty {
  text-align: center;
  color: #999;
  padding: 2rem;
}

.backtrace-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.backtrace-frame {
  border: 1px solid #e0e0e0;
  border-radius: 4px;
  padding: 1rem;
  background-color: #f9f9f9;
}

.frame-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.5rem;
  font-family: 'Monaco', 'Courier New', monospace;
  font-size: 0.9rem;
}

.frame-number {
  background-color: #3498db;
  color: white;
  padding: 0.25rem 0.5rem;
  border-radius: 3px;
  font-weight: 600;
}

.frame-file {
  color: #2980b9;
  font-weight: 500;
}

.frame-function {
  color: #666;
}

.frame-code,
.frame-context {
  margin-top: 0.5rem;
  background-color: #2d2d2d;
  color: #f8f8f2;
  padding: 0.75rem;
  border-radius: 3px;
  overflow-x: auto;
}

.frame-code pre,
.frame-context pre {
  margin: 0;
  font-family: 'Monaco', 'Courier New', monospace;
  font-size: 0.85rem;
  line-height: 1.5;
}

.frame-code code,
.frame-context code {
  color: inherit;
}
</style>

<template>
  <div class="backtrace">
    <div v-if="!backtrace || backtrace.length === 0" class="empty-state">
      <div class="empty-state__icon">📭</div>
      <div class="empty-state__text">No backtrace available</div>
    </div>
    <div v-else>
      <div
        v-for="(frame, index) in backtrace"
        :key="index"
        class="backtrace__frame"
      >
        <div class="backtrace__frame-header" @click="toggleFrame(index)">
          <span class="backtrace__frame-number">{{ index + 1 }}</span>
          <span class="backtrace__frame-file" v-if="frame.file">
            {{ frame.file }}<span v-if="frame.line" class="backtrace__frame-line">:{{ frame.line }}</span>
          </span>
          <span class="text-muted" v-if="frame.function">
            in <span class="code">{{ frame.function }}</span>
          </span>
        </div>
        <div v-if="expandedFrames.has(index)" class="backtrace__code">
          <div v-if="frame.code" class="backtrace__code-line" :class="{ 'is-highlighted': true }">
            <span class="backtrace__line-number">{{ frame.line }}</span>
            <span class="backtrace__line-content">{{ frame.code }}</span>
          </div>
          <div v-if="frame.context">
            <div v-for="(line, lineIndex) in frame.context" :key="lineIndex" class="backtrace__code-line">
              <span class="backtrace__line-number">{{ lineIndex + 1 }}</span>
              <span class="backtrace__line-content">{{ line }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'

defineProps({
  backtrace: {
    type: Array,
    default: () => []
  }
})

const expandedFrames = ref(new Set([0])) // First frame expanded by default

const toggleFrame = (index) => {
  if (expandedFrames.value.has(index)) {
    expandedFrames.value.delete(index)
  } else {
    expandedFrames.value.add(index)
  }
}
</script>

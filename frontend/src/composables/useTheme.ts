import { ref, computed } from 'vue'

const theme = ref<'light' | 'dark'>('light')

function initTheme() {
  const saved = localStorage.getItem('theme')
  if (saved === 'light' || saved === 'dark') {
    theme.value = saved
  } else {
    const systemPrefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
    theme.value = systemPrefersDark ? 'dark' : 'light'
  }
  applyTheme()
}

function applyTheme() {
  document.documentElement.setAttribute('data-theme', theme.value)
  localStorage.setItem('theme', theme.value)
}

export function useTheme() {
  const toggleIcon = computed(() => (theme.value === 'dark' ? '\u2600\uFE0F' : '\u{1F319}'))

  function toggleTheme() {
    theme.value = theme.value === 'dark' ? 'light' : 'dark'
    applyTheme()
  }

  initTheme()

  return { theme, toggleIcon, toggleTheme }
}

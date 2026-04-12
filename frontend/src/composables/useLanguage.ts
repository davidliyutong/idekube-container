import { ref, computed } from 'vue'

const lang = ref<'en' | 'zh'>('zh')

function initLang() {
  const saved = localStorage.getItem('language')
  if (saved === 'en' || saved === 'zh') {
    lang.value = saved
  }
}

export function useLanguage() {
  const buttonLabel = computed(() => (lang.value === 'zh' ? 'EN' : '\u4E2D'))

  function toggleLanguage() {
    lang.value = lang.value === 'zh' ? 'en' : 'zh'
    localStorage.setItem('language', lang.value)
  }

  initLang()

  return { lang, buttonLabel, toggleLanguage }
}
